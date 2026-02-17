import SwiftUI

struct TaskListView: View {
    @Binding var tasks: [TaskItem]

    var body: some View {
        List {
            ForEach($tasks) { $task in
                HStack {
                    Button { task.isDone.toggle() } label: {
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)

                    Text(task.title)
                }
            }
        }
        .navigationTitle("Список задач")
    }
}

#Preview {
    StatefulPreviewWrapper([
        TaskItem(title: "Купить молоко"),
        TaskItem(title: "Позвонить Ване"),
        TaskItem(title: "Написать клиенту")
    ]) { tasks in
        NavigationStack {
            TaskListView(tasks: tasks)
        }
    }
}
