//
//  TaskRow.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI
import SwiftData

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    let task: TaskModel

    var body: some View {
        HStack(spacing: 12) {
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
    }
}


#Preview {
    
}
