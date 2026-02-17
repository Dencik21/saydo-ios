//
//  TaskRow.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI


struct TaskRow: View {
    @Binding var task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Button { task.isDone.toggle() } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)

                if let date = task.dueDate {
                    Text(date.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}


#Preview {
    TaskRow(task: .constant(TaskItem(title: "Купить молоко", dueDate: Date())))
        .padding()
}
