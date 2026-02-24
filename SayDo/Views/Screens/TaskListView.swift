import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var context

    // Показать все задачи (можешь потом добавить фильтры/сортировки)
    @Query(sort: [SortDescriptor(\TaskModel.createdAt, order: .reverse)])
    private var tasks: [TaskModel]

    var body: some View {
        List {
            if tasks.isEmpty {
                EmptyStateCard(title: "Пока задач нет 🎉", subtitle: "" )
                   
            } else {
                ForEach(tasks) { task in
                    HStack {
                        Button {
                            task.isDone.toggle()
                            try? context.save()
                        } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)

                            if let due = task.dueDate {
                                Text(due, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Удалить", role: .destructive) {
                            context.delete(task)
                            try? context.save()
                        }
                    }
                }
            }
        }
        .cardListStyle()
        .navigationTitle("Список задач")
    }
}

#Preview {
    NavigationStack {
        TaskListView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}
