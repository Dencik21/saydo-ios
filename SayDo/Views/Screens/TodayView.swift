//
//  TodayView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//


import SwiftUI

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: TaskStore
    private let cal = Calendar.current

    var body: some View {
        List {
            ForEach($store.tasks) { $task in
                if let d = task.dueDate, cal.isDateInToday(d), !task.isDone {
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
        .navigationTitle("Today")
    }
}


#Preview {
    TodayView()
        .environmentObject(TaskStore())
}
