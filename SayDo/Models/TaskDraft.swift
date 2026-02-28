import Foundation

struct TaskDraft: Identifiable, Hashable {

    // MARK: - Identity
    var id: UUID = UUID()

    // MARK: - Content
    var title: String
    var dueDate: Date?

    /// Address string that can be used for Map/Calendar location
    var address: String?

    /// Optional coordinate after geocoding
    var coordinate: Coordinate?

    // MARK: - Reminder
    var reminderEnabled: Bool = false
    var reminderMinutesBefore: Int = 10

    // MARK: - Priority (0 normal, 1 important, 2 urgent)
    var priorityRaw: Int = 0

    // MARK: - Custom Equatable/Hashable (ignore id)

    static func == (lhs: TaskDraft, rhs: TaskDraft) -> Bool {
        lhs.title == rhs.title &&
        lhs.dueDate == rhs.dueDate &&
        lhs.address == rhs.address &&
        lhs.coordinate == rhs.coordinate &&
        lhs.reminderEnabled == rhs.reminderEnabled &&
        lhs.reminderMinutesBefore == rhs.reminderMinutesBefore &&
        lhs.priorityRaw == rhs.priorityRaw
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(dueDate)
        hasher.combine(address)
        hasher.combine(coordinate)
        hasher.combine(reminderEnabled)
        hasher.combine(reminderMinutesBefore)
        hasher.combine(priorityRaw)
    }
}
