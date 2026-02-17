//
//  InboxView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//


import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var store: TaskStore

    var body: some View {
        List {
            ForEach($store.tasks) { $task in
                if task.dueDate == nil && !task.isDone {
                    HStack {
                        Button { task.isDone.toggle() } label: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        Text(task.title)
                    }
                }
            }
        }
        .navigationTitle("Inbox")
    }
}


#Preview {
   InboxView()
        .environmentObject(TaskStore())
}
