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
        TaskListView(tasks: $store.tasks)
            .navigationTitle("Inbox")
    }
}

#Preview {
   InboxView()
        .environmentObject(TaskStore())
}
