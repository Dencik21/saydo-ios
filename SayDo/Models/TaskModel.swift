import Foundation
import SwiftData


@Model
final class TaskModel {
    @Attribute(.unique) var id: UUID

    var title: String
    var dueDate: Date?
    var isDone: Bool
    var createdAt: Date

    // Reminder
    var reminderEnabled: Bool = false
    var reminderMinutesBefore: Int = 10
    var notificationID: String? = nil

    // Calendar
    var calendarEventID: String? = nil

    // ✅ Location (optional)
    var address: String? = nil
    var locationLat: Double? = nil
    var locationLon: Double? = nil

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

extension TaskModel {
    convenience init(from draft: TaskDraft) {
        self.init(
            id: draft.id,
            title: draft.title,
            dueDate: draft.dueDate,
            isDone: false,
            createdAt: .now
        )
        self.reminderEnabled = draft.reminderEnabled
        self.reminderMinutesBefore = draft.reminderMinutesBefore

        self.address = draft.address
        self.locationLat = draft.coordinate?.lat
        self.locationLon = draft.coordinate?.lon
    }
}
