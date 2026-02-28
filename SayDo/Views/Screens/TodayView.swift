import SwiftUI
import SwiftData
import CoreLocation

struct TodayView: View {

    @Environment(\.modelContext) private var context
    @Query private var allTasks: [TaskModel]

    private let actions = TaskActionService.shared

    init() {
        _allTasks = Query(
            filter: #Predicate<TaskModel> { task in
                task.isDone == false && task.dueDate != nil
            },
            sort: [SortDescriptor(\TaskModel.dueDate, order: .forward)]
        )
    }

    private var todayTasks: [TaskModel] {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let d = task.dueDate else { return false }
            return cal.isDateInToday(d)
        }
    }

    var body: some View {
        List {
            if todayTasks.isEmpty {
                EmptyStateCard(
                    title: "На сегодня задач нет 🎉",
                    subtitle: "Добавь задачу — она появится здесь."
                )
            } else {
                ForEach(todayTasks) { task in
                    TaskRow(
                        task: task,
                        onToggleDone: { actions.toggleDone($0, in: context) },
                        onOpen: { _ in },
                        onCacheCoordinate: { t, coord in
                            actions.cacheCoordinate(coord, for: t, in: context)
                        }
                    )
                    .cardRowStyle()
                    .swipeActions(edge: .trailing) {
                        Button("Inbox") { actions.moveToInbox(task, in: context) }
                            .tint(.orange)

                        Button("Удалить", role: .destructive) {
                            actions.delete(task, in: context)
                        }
                    }
                }
            }
        }
        .cardListStyle()
        .navigationTitle("Today")
    }
}

#Preview {
    NavigationStack { TodayView() }
        .modelContainer(for: TaskModel.self, inMemory: true)
}
