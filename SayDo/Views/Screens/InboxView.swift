import SwiftUI
import SwiftData

struct InboxView: View {
    @Environment(\.modelContext) private var context
    
    @Query private var tasks: [TaskModel]
    
    init() {
        _tasks = Query(
            filter: #Predicate<TaskModel> { task in
                task.isDone == false && task.dueDate == nil
            },
            sort: [SortDescriptor(\TaskModel.createdAt, order: .reverse)]
        )
    }
    
    var body: some View {
        List {
            if tasks.isEmpty {
                
                EmptyStateCard(
                       title: "На сегодня задач нет 🎉",
                       subtitle: "Добавь задачу — она появится здесь."
                   )
            } else {
                ForEach(tasks) { task in
                    TaskRow(task: task)
                        .cardRowStyle()
                        .swipeActions(edge: .trailing) {
                            Button("Today") {
                               
                                task.dueDate = Calendar.current.startOfDay(for: Date())
                                save()
                            }
                            
                            .tint(.blue)
                            
                            Button("Tomorrow") {
                                task.dueDate = startOfTomorrow()
                                save()
                            }
                            .tint(.green)
                            
                            Button("Удалить", role: .destructive) {
                                context.delete(task)
                                save()
                        }
                    }
                }
            }
        }
        .cardListStyle()
        .navigationTitle("Inbox")
    }
    
    private func save() {
        do { try context.save() }
        catch { print("Save error:", error) }
    }
    
    private func startOfTomorrow() -> Date {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: 1, to: startToday) ?? Date()
    }
}
