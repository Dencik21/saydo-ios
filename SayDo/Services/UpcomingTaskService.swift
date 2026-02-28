//
//  UpcomingTaskService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//


import Foundation
import SwiftData

@MainActor
final class UpcomingTaskService {

    static let shared = UpcomingTaskService()
    private init() {}

    // MARK: - Public API

    func toggleDone(_ task: TaskModel, in context: ModelContext) {
        task.isDone.toggle()

        if task.isDone {
            removeCalendarEventIfNeeded(for: task)
            cancelNotificationIfNeeded(for: task)

            task.reminderEnabled = false
            task.notificationID = nil
        }

        save(context)
    }

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

    /// ✅ Если пользователь удалил событие из Apple Calendar — удаляем задачу в приложении
    func reconcileCalendarDeletions(tasks: [TaskModel], in context: ModelContext) async {
        let auth = await CalendarService.shared.requestAccessIfNeeded()
        guard auth == .authorized else { return }

        var changed = false

        for t in tasks {
            guard let eventID = t.calendarEventID else { continue }

            if CalendarService.shared.eventExists(eventID: eventID) == false {
                cancelNotificationIfNeeded(for: t)
                context.delete(t)
                changed = true
            }
        }

        if changed {
            save(context)
        }
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
