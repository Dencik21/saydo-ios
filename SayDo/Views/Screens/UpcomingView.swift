//
//  UpcomingView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI
import SwiftData

struct UpcomingView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskModel]

    init() {
        _tasks = Query(
            filter: #Predicate<TaskModel> { task in
                task.isDone == false && task.dueDate != nil
            },
            sort: [SortDescriptor(\TaskModel.dueDate, order: .forward)]
        )
    }

    var body: some View {
        List {
            if tasks.isEmpty {
                Text("Будущих задач нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedKeys, id: \.self) { key in
                    Section(sectionTitle(for: key)) {
                        ForEach(grouped[key] ?? []) { task in
                            TaskRow(task: task)
                                .swipeActions(edge: .trailing) {
                                    Button("Inbox") { task.dueDate = nil; save() }
                                        .tint(.orange)
                                    Button("Удалить", role: .destructive) {
                                        context.delete(task); save()
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Upcoming")
    }

    // MARK: - Grouping

    private var grouped: [Date: [TaskModel]] {
        let cal = Calendar.current
        return Dictionary(grouping: tasks) { task in
            cal.startOfDay(for: task.dueDate!)
        }
    }

    private var groupedKeys: [Date] {
        grouped.keys.sorted()
    }

    private func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Сегодня" }
        if cal.isDateInTomorrow(day) { return "Завтра" }

        // "Среда, 19 февраля"
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func save() { try? context.save() }
}


#Preview {
    NavigationStack {
        UpcomingView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}

