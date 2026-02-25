import Foundation
import SwiftData

@Model
final class TaskModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var createdAt: Date
    var reminderEnabled: Bool = false
    var reminderMinutesBefore: Int = 10
    var notificationID: String? = nil
    var calendarEventID: String? = nil
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
