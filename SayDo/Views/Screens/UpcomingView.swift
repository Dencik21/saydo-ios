//
//  UpcomingView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//

import SwiftUI
import SwiftData
import CoreLocation

struct UpcomingView: View {

    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskModel]
    @State private var selectedTask: TaskModel?

    @State private var mode: Mode = .list
    @State private var monthAnchor: Date = Date()
    @State private var selectedDay: Date? = nil

    private let actions = TaskActionService.shared

    init() {
        _tasks = Query(
            filter: #Predicate<TaskModel> { task in
                task.isDone == false && task.dueDate != nil
            },
            sort: [SortDescriptor(\TaskModel.dueDate, order: .forward)]
        )
    }

    var body: some View {
        Group {
            switch mode {
            case .list:
                listView
            case .calendar:
                calendarView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .navigationTitle("Upcoming")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { modeSwitcher }
        }
        .sheet(item: $selectedTask) { TaskEditorView(task: $0) }

        // ✅ reconcile: если пользователь удалил событие в Apple Calendar — удаляем задачу в приложении
        .task {
            await actions.reconcileCalendarDeletions(tasks: tasks, in: context)
        }
    }
}

// MARK: - Mode switcher

private extension UpcomingView {

    var modeSwitcher: some View {
        HStack(spacing: 0) {
            modeButton(icon: "list.bullet", mode: .list)
            modeButton(icon: "calendar", mode: .calendar)
        }
        .padding(4)
        .glassPill()
    }

    func modeButton(icon: String, mode: Mode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { self.mode = mode }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
                .background(self.mode == mode ? Color.white.opacity(0.16) : .clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}

// MARK: - LIST MODE

private extension UpcomingView {

    var listView: some View {
        List {
            if tasks.isEmpty {
                EmptyStateCard(
                    title: "Будущих задач нет",
                    subtitle: "Добавь задачу с датой — она появится здесь."
                )
            } else {
                ForEach(groupedKeys, id: \.self) { day in
                    Section(sectionTitle(for: day)) {
                        ForEach(grouped[day] ?? []) { task in
                            TaskRow(
                                task: task,
                                onToggleDone: { actions.toggleDone($0, in: context) },
                                onOpen: { selectedTask = $0 },
                                onCacheCoordinate: { t, coord in
                                    actions.cacheCoordinate(coord, for: t, in: context)
                                }
                            )
                            .cardRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button("Inbox") { actions.moveToInbox(task, in: context) }
                                    .tint(.orange)

                                Button("Удалить", role: .destructive) {
                                    actions.delete(task, in: context)
                                }
                            }
                        }
                    }
                }
            }
        }
        .cardListStyle()
    }

    var grouped: [Date: [TaskModel]] {
        let cal = Calendar.current
        return Dictionary(grouping: tasks) { task in
            cal.startOfDay(for: task.dueDate!) // dueDate != nil по фильтру
        }
    }

    var groupedKeys: [Date] {
        grouped.keys.sorted()
    }

    func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Сегодня" }
        if cal.isDateInTomorrow(day) { return "Завтра" }
        if let afterTomorrow = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date())),
           cal.isDate(day, inSameDayAs: afterTomorrow) { return "Послезавтра" }
        return russianWeekdayDayMonth(from: day)
    }

    func russianWeekdayDayMonth(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "EEEE, d MMMM"
        return df.string(from: date)
    }
}

// MARK: - CALENDAR MODE

private extension UpcomingView {

    var calendarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                monthHeader
                weekdayHeader
                monthGrid
                dayDetails
                Spacer(minLength: 24)
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
    }

    var monthHeader: some View {
        HStack {
            Button {
                monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                selectedDay = nil
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle(monthAnchor))
                .font(.headline)

            Spacer()

            Button {
                monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                selectedDay = nil
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .glassCard()
    }

    var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(weekdaySymbolsRu, id: \.self) { s in
                Text(s)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
    }

    var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
            ForEach(monthDays(for: monthAnchor), id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(12)
        .glassCard()
    }

    @ViewBuilder
    var dayDetails: some View {
        if let selectedDay {
            VStack(alignment: .leading, spacing: 10) {
                Text(dayTitle(selectedDay))
                    .font(.headline)

                let items = tasksForDay(selectedDay)

                if items.isEmpty {
                    Text("На этот день задач нет")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(items) { task in
                            TaskRow(
                                task: task,
                                onToggleDone: { actions.toggleDone($0, in: context) },
                                onOpen: { selectedTask = $0 },
                                onCacheCoordinate: { t, coord in
                                    actions.cacheCoordinate(coord, for: t, in: context)
                                }
                            )
                            .cardRowStyle()
                            .swipeActions(edge: .trailing) {
                                Button("Inbox") { actions.moveToInbox(task, in: context) }
                                    .tint(.orange)

                                Button("Удалить", role: .destructive) {
                                    actions.delete(task, in: context)
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .glassCard()
        } else {
            EmptyStateCard(
                title: "Выбери день",
                subtitle: "Нажми на дату в календаре — покажу задачи на этот день."
            )
            .padding(14)
            .glassCard()
        }
    }

    func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isCurrentMonth = cal.component(.month, from: day) == cal.component(.month, from: monthAnchor)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)

        return Button {
            selectedDay = cal.startOfDay(for: day)
        } label: {
            VStack(spacing: 4) {
                Text("\(cal.component(.day, from: day))")
                    .font(.callout)
                    .frame(maxWidth: .infinity)

                Circle()
                    .frame(width: 5, height: 5)
                    .opacity(hasTasks(on: day) ? 1 : 0)
            }
            .padding(.vertical, 8)
            .foregroundStyle(isCurrentMonth ? .primary : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday ? Color.white.opacity(0.25) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var weekdaySymbolsRu: [String] {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        let s = df.shortStandaloneWeekdaySymbols ?? ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"]
        return Array(s.dropFirst()) + [s.first ?? "Вс"]
    }

    func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date).capitalized
    }

    func dayTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "EEEE, d MMMM"
        return df.string(from: date)
    }

    func monthDays(for anchor: Date) -> [Date] {
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
        let range = cal.range(of: .day, in: .month, for: startOfMonth)!
        let weekday = cal.component(.weekday, from: startOfMonth) // 1=Sun
        let mondayBased = (weekday + 5) % 7 // 0=Mon
        let prefix = mondayBased

        var days: [Date] = []

        if prefix > 0 {
            for i in stride(from: prefix, to: 0, by: -1) {
                days.append(cal.date(byAdding: .day, value: -i, to: startOfMonth)!)
            }
        }

        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: startOfMonth)!)
        }

        while days.count % 7 != 0 {
            let last = days.last!
            days.append(cal.date(byAdding: .day, value: 1, to: last)!)
        }

        return days
    }

    func tasksForDay(_ day: Date) -> [TaskModel] {
        let cal = Calendar.current
        return tasks.filter { t in
            guard let d = t.dueDate else { return false }
            return cal.isDate(d, inSameDayAs: day)
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func hasTasks(on day: Date) -> Bool {
        !tasksForDay(day).isEmpty
    }
}

private enum Mode { case list, calendar }

// MARK: - Glass Styles

private extension View {

    func glassPill() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    func glassCard() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview("Upcoming — sample tasks (address only)") {
    let container = try! ModelContainer(
        for: TaskModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let cal = Calendar.current
    let now = Date()

    let t1 = TaskModel(title: "Встреча в кафе", dueDate: cal.date(byAdding: .day, value: 1, to: now)!)
    t1.address = "Hauptstraße 10, Köln"

    let t2 = TaskModel(title: "Стоматолог", dueDate: cal.date(byAdding: .day, value: 3, to: now)!)
    t2.address = "Berliner Allee 5, Düsseldorf"
    t2.reminderEnabled = true

    let t3 = TaskModel(title: "Купить молоко", dueDate: cal.date(byAdding: .day, value: 2, to: now)!)
    t3.reminderEnabled = true

    context.insert(t1)
    context.insert(t2)
    context.insert(t3)

    return NavigationStack { UpcomingView() }
        .modelContainer(container)
}
