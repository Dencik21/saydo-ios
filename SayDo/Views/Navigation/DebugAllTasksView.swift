//
//  DebugAllTasksView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 18.02.26.
//

import SwiftUI
import SwiftData

struct DebugAllTasksView: View {
    @Query(sort: [SortDescriptor(\TaskModel.createdAt, order: .reverse)])
    private var tasks: [TaskModel]

    var body: some View {
        List(tasks) { t in
            VStack(alignment: .leading, spacing: 4) {
                Text(t.title)
                Text("due: \(t.dueDate?.formatted() ?? "nil") | done: \(t.isDone ? "yes" : "no")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardListStyle()
        .navigationTitle("DEBUG: All Tasks (\(tasks.count))")
    }
}

#Preview {
    NavigationStack { DebugAllTasksView() }
        .modelContainer(for: TaskModel.self, inMemory: true)
}
