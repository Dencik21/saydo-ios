//
//  UpcomingView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI


struct UpcomingView: View {
    @EnvironmentObject private var store: TaskStore
    @StateObject private var vm = UpcomingViewModel()

    var body: some View {
        List {
            ForEach(vm.makeSections(from: store.tasks)) { section in
                Section(header: Text(section.title)) {
                    ForEach(section.taskIDs, id: \.self) { id in
                        if let binding = binding(for: id) {
                            TaskRow(task: binding)
                        }
                    }
                }
            }
        }
        .navigationTitle("Plan")
    }

    private func binding(for id: UUID) -> Binding<TaskItem>? {
        guard let idx = store.tasks.firstIndex(where: { $0.id == id }) else { return nil }
        return $store.tasks[idx]
    }
}


#Preview {
    NavigationStack {
        UpcomingView()
            .environmentObject(TaskStore())
    }
}
