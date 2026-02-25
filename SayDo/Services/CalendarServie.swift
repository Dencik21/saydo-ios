//
//  CalendrServie.swift
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
    
    // Mark: Premissions
    
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

    /// Создаёт/обновляет event и возвращает `eventIdentifier`
    func upsertEvent(
        existingEventID: String?,
               title: String,
               dueDate: Date?,
               reminderEnabled: Bool,
               reminderMinutesBefore: Int
    ) throws  -> String {
        let event: EKEvent
        if let id = existingEventID, let exsiting = store.event(withIdentifier: id) {
            event = exsiting
        } else {
            event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
        }
        event.title = title
        
        if let due = dueDate {
                // Считаем dueDate как “момент события”
                // (если хочешь all-day — скажи, поменяем)
                event.startDate = due
                event.endDate = Calendar.current.date(byAdding: .minute, value: 30, to: due) ?? due
                event.isAllDay = false
            } else {
                // Нет даты → не создаём событие
                // Лучше вернуть existingEventID или кинуть ошибку — выбираю ошибку, чтобы было явно
                throw NSError(domain: "CalendarService", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Task has no dueDate"
                ])
            }
        
        // Удаляем старые alarms и ставим новый (если надо)
              if let alarms = event.alarms, !alarms.isEmpty {
                  event.alarms = []
              }
              if reminderEnabled {
                  let offset = -TimeInterval(reminderMinutesBefore * 60)
                  event.addAlarm(EKAlarm(relativeOffset: offset))
              }
        try store.save(event, span: .thisEvent, commit: true)
               return event.eventIdentifier
    }
    func deleteEvent(eventID: String) throws {
            guard let event = store.event(withIdentifier: eventID) else { return }
            try store.remove(event, span: .thisEvent, commit: true)
        }
}
