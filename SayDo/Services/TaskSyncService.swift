//
//  TaskSyncService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//


import Foundation
import SwiftData

final class TaskSyncService {

    static let shared = TaskSyncService()
    private init() {}

    /// Основной сценарий после Confirm:
    /// - вставить задачи в SwiftData
    /// - (опционально) синхронизировать с Calendar
    /// - синхронизировать Notifications
    func persistAndSync(
        tasks: [TaskModel],
        in context: ModelContext,
        addToCalendar: Bool
    ) async {

        // 1) SwiftData insert + save
        prepareForInsert(tasks)
        tasks.forEach { context.insert($0) }

        do {
            try context.save()
        } catch {
            print("❌ SwiftData save error:", error)
        }

        // 2) Calendar (optional)
        if addToCalendar {
            await syncCalendar(tasks: tasks)
            do {
                try context.save()
            } catch {
                print("❌ SwiftData save after calendar error:", error)
            }
        }

        // 3) Notifications
        await syncNotifications(tasks: tasks)
    }

    // MARK: - SwiftData preparation

    private func prepareForInsert(_ tasks: [TaskModel]) {
        for t in tasks {
            if t.reminderEnabled {
                t.notificationID = t.notificationID ?? UUID().uuidString
            } else {
                t.notificationID = nil
            }
        }
    }

    // MARK: - Calendar

    private func syncCalendar(tasks: [TaskModel]) async {
        let auth = await CalendarService.shared.requestAccessIfNeeded()
        guard auth == .authorized else { return }

        for t in tasks {
            guard t.dueDate != nil else { continue }

            do {
                let id = try CalendarService.shared.upsertEvent(
                    existingEventID: t.calendarEventID,
                    taskID: t.id,
                    title: t.title,
                    dueDate: t.dueDate,
                    address: t.address,
                    reminderEnabled: t.reminderEnabled,
                    reminderMinutesBefore: t.reminderMinutesBefore
                )
                t.calendarEventID = id
            } catch {
                print("❌ Calendar upsert error:", error)
            }
        }
    }

    // MARK: - Notifications

    private func syncNotifications(tasks: [TaskModel]) async {
        for t in tasks {
            await scheduleIfNeeded(task: t)
        }
    }

    private func scheduleIfNeeded(task: TaskModel) async {
        guard let id = task.notificationID else { return }

        guard task.isDone == false,
              task.reminderEnabled,
              let due = task.dueDate
        else {
            await NotificationService.shared.cancel(id: id)
            return
        }

        let ok = await NotificationService.shared.requestAuthIfNeeded()
        guard ok else { return }

        let fireDate = due.addingTimeInterval(TimeInterval(-task.reminderMinutesBefore * 60))

        guard fireDate > Date() else {
            await NotificationService.shared.cancel(id: id)
            return
        }

        await NotificationService.shared.schedule(
            id: id,
            title: task.title,
            fireDate: fireDate
        )
    }
}
