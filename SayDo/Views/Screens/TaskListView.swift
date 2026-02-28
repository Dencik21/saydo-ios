import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\TaskModel.createdAt, order: .reverse)])
    private var tasks: [TaskModel]

    @State private var selectedTask: TaskModel?

    var body: some View {
        List {
            if tasks.isEmpty {
                EmptyStateCard(title: "Пока задач нет 🎉", subtitle: "")
            } else {
                ForEach(tasks) { task in
                    // Если хочешь открывать редактор по тапу на строку — оставь Button
                    Button {
                        selectedTask = task
                    } label: {
                        row(task)
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $selectedTask) { TaskEditorView(task: $0) } // если есть такой экран
    }

    private func row(_ task: TaskModel) -> some View {
        HStack {
            Button {
                task.isDone.toggle()
                try? context.save()
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless) // ✅ ключ для кнопок внутри List/строки
            .foregroundStyle(task.isDone ? .green : .secondary)

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
    }
}

#Preview {
    NavigationStack { TaskListView() }
        .modelContainer(for: TaskModel.self, inMemory: true)
}
