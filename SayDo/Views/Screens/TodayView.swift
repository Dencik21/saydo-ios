
import SwiftUI
import SwiftData


struct TodayView: View {
    @Environment(\.modelContext) private var context
    
    @Query private var allTasks: [TaskModel]
    
    init() {
        _allTasks = Query(
            filter: #Predicate<TaskModel> { task in
                task.isDone == false && task.dueDate != nil
            },
            sort: [SortDescriptor(\TaskModel.dueDate, order: .forward)]
        )
    }
    
    var body: some View {
        let todayTasks = allTasks.filter { task in
            guard let d = task.dueDate else { return false }
            return Calendar.current.isDateInToday(d)
        }
        
        return List {
            if todayTasks.isEmpty {
                EmptyStateCard(
                       title: "На сегодня задач нет 🎉",
                       subtitle: "Добавь задачу — она появится здесь."
                   )
            } else {
                ForEach(todayTasks) { task in
                    TaskRow(task: task)
                        .cardRowStyle()
                        .swipeActions(edge: .trailing) {
                            Button("Inbox") { moveToInbox(task) }
                                .tint(.orange)

                            Button("Удалить", role: .destructive) { deleteTask(task) }
                        }
                }
            }
        }
        .cardListStyle()
        .navigationTitle("Today")
    }
    
    private func save() {
        do { try context.save() }
        catch { print("Save error:", error) }
    }
    private func removeCalendarEventIfNeeded(for task: TaskModel) {
        guard let eventID = task.calendarEventID else { return }
        try? CalendarService.shared.deleteEvent(eventID: eventID)
        task.calendarEventID = nil
    }

    private func moveToInbox(_ task: TaskModel) {
        // 1) убрать событие из календаря (если было)
        removeCalendarEventIfNeeded(for: task)

        // 2) превратить в Inbox-задачу
        task.dueDate = nil
        task.reminderEnabled = false
        task.notificationID = nil  // если ты уведомления отдельно чистишь — ок, но это логично

        save()
    }

    private func deleteTask(_ task: TaskModel) {
        // 1) убрать событие из календаря
        removeCalendarEventIfNeeded(for: task)

        // 2) удалить из SwiftData
        context.delete(task)
        save()
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}
