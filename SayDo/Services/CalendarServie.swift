//
//  CalendarService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 25.02.26.
//

import Foundation
import EventKit

final class CalendarService {
    static let shared = CalendarService()
    private init() {}

    private let store = EKEventStore()

    enum CalendarAuthResult {
        case authorized
        case denied
        case restricted
        case notDetermined
        case unknown
    }

    // MARK: - Permissions

    @MainActor
    func requestAccessIfNeeded() async -> CalendarAuthResult {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            return .authorized

        case .fullAccess:
            return .authorized

        case .writeOnly:
            return .authorized

        case .denied:
            return .denied

        case .restricted:
            return .restricted

        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                return granted ? .authorized : .denied
            } catch {
                return .denied
            }

        @unknown default:
            return .unknown
        }
    }

    // MARK: - Create/Update

    /// ✅ Создаёт/обновляет event и возвращает `eventIdentifier`
    /// Важно: eventIdentifier может "протухать", поэтому мы дополнительно привязываем событие к taskID через event.url
    func upsertEvent(
        existingEventID: String?,
        taskID: UUID,
        title: String,
        dueDate: Date?,
        reminderEnabled: Bool,
        reminderMinutesBefore: Int
    ) throws -> String {

        guard let due = dueDate else {
            throw NSError(domain: "CalendarService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Task has no dueDate"
            ])
        }

        // 1) Пытаемся взять по eventIdentifier
        if let id = existingEventID,
           let existing = store.event(withIdentifier: id) {
            return try updateAndSave(
                existing,
                taskID: taskID,
                title: title,
                due: due,
                reminderEnabled: reminderEnabled,
                reminderMinutesBefore: reminderMinutesBefore
            )
        }

        // 2) Fallback: ищем событие по нашему taskID (event.url) рядом с dueDate
        if let found = findEventByTaskID(taskID, near: due) {
            return try updateAndSave(
                found,
                taskID: taskID,
                title: title,
                due: due,
                reminderEnabled: reminderEnabled,
                reminderMinutesBefore: reminderMinutesBefore
            )
        }

        // 3) Иначе создаём новое
        let event = EKEvent(eventStore: store)
        event.calendar = store.defaultCalendarForNewEvents

        return try updateAndSave(
            event,
            taskID: taskID,
            title: title,
            due: due,
            reminderEnabled: reminderEnabled,
            reminderMinutesBefore: reminderMinutesBefore
        )
    }

    private func updateAndSave(
        _ event: EKEvent,
        taskID: UUID,
        title: String,
        due: Date,
        reminderEnabled: Bool,
        reminderMinutesBefore: Int
    ) throws -> String {

        event.title = title

        // dueDate считаем моментом события
        event.startDate = due
        event.endDate = Calendar.current.date(byAdding: .minute, value: 30, to: due) ?? due
        event.isAllDay = false

        // ✅ стабильная привязка “это событие принадлежит этой задаче”
        event.url = URL(string: "saydo://task/\(taskID.uuidString)")

        // alarms
        event.alarms = []
        if reminderEnabled {
            let offset = -TimeInterval(reminderMinutesBefore * 60)
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }

        try store.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    private func findEventByTaskID(_ taskID: UUID, near due: Date) -> EKEvent? {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: due) ?? due
        let end = cal.date(byAdding: .day, value: 7, to: due) ?? due

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)

        let needle = "saydo://task/\(taskID.uuidString)".lowercased()
        return events.first(where: { $0.url?.absoluteString.lowercased() == needle })
    }

    func deleteEvent(eventID: String) throws {
        guard let event = store.event(withIdentifier: eventID) else { return }
        try store.remove(event, span: .thisEvent, commit: true)
    }

    /// ✅ Проверка "событие существует?" — нужно для reconcile (удалили в календаре → удалить в приложении)
    func eventExists(eventID: String) -> Bool {
        store.event(withIdentifier: eventID) != nil
    }
}
