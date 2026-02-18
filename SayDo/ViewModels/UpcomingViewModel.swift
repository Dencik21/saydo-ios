import Foundation
import Combine

@MainActor
final class UpcomingViewModel: ObservableObject {

    struct SectionModel: Identifiable {
        let id = UUID()
        let title: String
        let taskIDs: [UUID]
    }

    private let cal: Calendar

    init(calendar: Calendar = .current) {
        self.cal = calendar
    }

    func makeSections(from tasks: [TaskModel]) -> [SectionModel] {
        let active = tasks.filter { !$0.isDone }

        let inbox = active.filter { $0.dueDate == nil }

        let dated: [(TaskModel, Date)] = active.compactMap { task in
            guard let d = task.dueDate else { return nil }
            return (task, d)
        }

        let todayStart = cal.startOfDay(for: Date())
        let dayAfterTomorrowStart = cal.date(byAdding: .day, value: 2, to: todayStart) ?? todayStart

        var sections: [SectionModel] = []

        let overdue = dated
            .filter { cal.startOfDay(for: $0.1) < todayStart }
            .sorted { $0.1 < $1.1 }
            .map { $0.0.id }
        if !overdue.isEmpty { sections.append(.init(title: "Overdue", taskIDs: overdue)) }

        let today = dated
            .filter { cal.isDateInToday($0.1) }
            .sorted { $0.1 < $1.1 }
            .map { $0.0.id }
        if !today.isEmpty { sections.append(.init(title: "Today", taskIDs: today)) }

        let tomorrow = dated
            .filter { cal.isDateInTomorrow($0.1) }
            .sorted { $0.1 < $1.1 }
            .map { $0.0.id }
        if !tomorrow.isEmpty { sections.append(.init(title: "Tomorrow", taskIDs: tomorrow)) }

        let future = dated
            .filter { cal.startOfDay(for: $0.1) >= dayAfterTomorrowStart }

        let grouped = Dictionary(grouping: future) { cal.startOfDay(for: $0.1) }
        let futureDates = grouped.keys.sorted()

        for date in futureDates {
            let ids = (grouped[date] ?? [])
                .sorted { $0.1 < $1.1 }
                .map { $0.0.id }

            let title = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            sections.append(.init(title: title, taskIDs: ids))
        }

        if !inbox.isEmpty {
            sections.append(.init(title: "Inbox", taskIDs: inbox.map { $0.id }))
        }

        return sections
    }
}
