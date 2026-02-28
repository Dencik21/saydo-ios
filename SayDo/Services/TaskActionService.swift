//
//  TaskActionService.swift
//  SayDo
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class TaskActionService {

    static let shared = TaskActionService()
    private init() {}

    // MARK: - Public Actions

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

    func cacheCoordinate(_ coord: CLLocationCoordinate2D, for task: TaskModel, in context: ModelContext) {
        task.locationLat = coord.latitude
        task.locationLon = coord.longitude
        save(context)
    }

    /// ✅ Если пользователь удалил событие в Apple Calendar — удаляем задачу в приложении
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

        if changed { save(context) }
    }
    
    // MARK: - Priority
    
    func setPriority(_ raw: Int, for task: TaskModel, in context: ModelContext) {
        task.priorityRaw = raw
        do { try context.save() } catch { print("Save error:", error) }
    }
    
    func markImportant(_ task: TaskModel, in context: ModelContext) { setPriority(1, for: task, in: context) }
    func markUrgent(_ task: TaskModel, in context: ModelContext) { setPriority(2, for: task, in: context) }
    func clearPriority(_ task: TaskModel, in context: ModelContext) { setPriority(0, for: task, in: context) }
    
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
