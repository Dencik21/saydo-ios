//
//  TodayTaskService.swift
//  SayDo
//

import Foundation
import SwiftData

@MainActor
final class TodayTaskService {

    static let shared = TodayTaskService()
    private init() {}

    func moveToInbox(_ task: TaskModel, in context: ModelContext) {
        removeCalendarEventIfNeeded(for: task)
        cancelNotificationIfNeeded(for: task)

        task.dueDate = nil
        task.reminderEnabled = false
        task.notificationID = nil

        save(context)
    }

    func delete(_ task: TaskModel, in context: ModelContext) {
        removeCalendarEventIfNeeded(for: task)
        cancelNotificationIfNeeded(for: task)

        context.delete(task)
        save(context)
    }

    // MARK: - Helpers

    private func save(_ context: ModelContext) {
        do { try context.save() }
        catch { print("❌ SwiftData save error:", error) }
    }

    private func cancelNotificationIfNeeded(for task: TaskModel) {
        guard let nid = task.notificationID else { return }
        Task { await NotificationService.shared.cancel(id: nid) }
    }

    private func removeCalendarEventIfNeeded(for task: TaskModel) {
        guard let eventID = task.calendarEventID else { return }
        do {
            try CalendarService.shared.deleteEvent(eventID: eventID)
        } catch {
            print("❌ Calendar delete error:", error)
        }
        task.calendarEventID = nil
    }
}
