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
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .lineLimit(2)

                if let due = task.dueDate {
                    Text(russianDate(due))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background)
                .shadow(radius: 6, y: 2)
        )
        .contentShape(Rectangle()) // чтобы тап по карточке работал везде
    }

    private func russianDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: date)
    }
}

#Preview {
    let container = try! ModelContainer(
        for: TaskModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let cal = Calendar.current
    let today = Date()
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    let afterTomorrow = cal.date(byAdding: .day, value: 2, to: today)!

    let t1 = TaskModel(title: "Пойти в спортзал", dueDate: afterTomorrow)
    let t2 = TaskModel(title: "Купить молоко завтра утром", dueDate: tomorrow)
    let t3 = TaskModel(title: "Встреча с друзьями в кафе", dueDate: cal.date(byAdding: .day, value: 4, to: today)!)

    context.insert(t1)
    context.insert(t2)
    context.insert(t3)

    return List {
        TaskRow(task: t1)
        TaskRow(task: t2)
        TaskRow(task: t3)
    }
    .modelContainer(container)
}
