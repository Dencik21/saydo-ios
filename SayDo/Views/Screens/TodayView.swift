
import SwiftUI
import SwiftData
import Foundation

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
                            Button("Inbox") {
                                task.dueDate = nil
                                save()
                            }
                            .tint(.orange)
                            
                            Button("Удалить", role: .destructive) {
                                context.delete(task)
                                save()
                            }
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
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}
