import SwiftUI
import SwiftData

struct UpcomingView: View {
    @Environment(\.modelContext) private var context
    @Query private var tasks: [TaskModel]
    @State private var selectedTask: TaskModel?
    
    
    @State private var mode: Mode = .list
    @State private var monthAnchor: Date = Date()      // какой месяц показываем
    @State private var selectedDay: Date? = nil        // выбранный день в календаре
    
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
            ToolbarItem(placement: .topBarTrailing) {
                Picker("", selection: $mode) {
                    Image(systemName: "list.bullet")
                        .tag(Mode.list)
                    Image(systemName: "calendar")
                        .tag(Mode.calendar)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
        }
        .sheet(item: $selectedTask) { TaskEditorView(task: $0) }
    }

    
    private var listView: some View {
        List {
            if tasks.isEmpty {
                Text("Будущих задач нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedKeys, id: \.self) { key in
                    Section(sectionTitle(for: key)) {
                        ForEach(grouped[key] ?? []) { task in
                            TaskRow(task: task)
                                .cardRowStyle()
                                .onTapGesture { selectedTask = task }
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
        .cardListStyle()
    }
    
    
    private var calendarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                
                // Header месяца
                HStack {
                    Button {
                        monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                        selectedDay = nil
                    } label: {
                        Image(systemName: "chevron.left")
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                
                // Дни недели
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                    ForEach(weekdaySymbolsRu, id: \.self) { s in
                        Text(s)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                
                // Сетка месяца
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                    ForEach(monthDays(for: monthAnchor), id: \.self) { day in
                        dayCell(day)
                    }
                }
                .padding(.horizontal)
                
                // Список задач выбранного дня
                if let selectedDay {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dayTitle(selectedDay))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        let items = tasksForDay(selectedDay)
                        
                        if items.isEmpty {
                            Text("На этот день задач нет")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(items) { task in
                                    TaskRow(task: task)
                                        .onTapGesture { selectedTask = task }
                                        .swipeActions(edge: .trailing) {
                                            Button("Inbox") { task.dueDate = nil; save() }
                                                .tint(.orange)
                                            Button("Удалить", role: .destructive) {
                                                context.delete(task); save()
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Выбери день в календаре")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 6)
                }
                
                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground))
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
        
        // Послезавтра (по желанию — ты просил)
        if let afterTomorrow = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: Date())),
           cal.isDate(day, inSameDayAs: afterTomorrow) {
            return "Послезавтра"
        }
        
        // "среда, 19 февраля" — всегда на русском
        return russianWeekdayDayMonth(from: day)
    }
    
    private func russianWeekdayDayMonth(from date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "EEEE, d MMMM"   // среда, 19 февраля
        return df.string(from: date)
    }
    
    private func save() { try? context.save() }
    
    private enum Mode: String, CaseIterable, Identifiable {
        case list = "Список"
        case calendar = "Календарь"
        var id: String { rawValue }
    }
    
    private var weekdaySymbolsRu: [String] {
        // Пн Вт Ср Чт Пт Сб Вс
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        // shortStandaloneWeekdaySymbols начинается с воскресенья, поэтому вручную переставим
        let s = df.shortStandaloneWeekdaySymbols ?? ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"]
        // делаем Пн..Вс
        return Array(s.dropFirst()) + [s.first ?? "Вс"]
    }
    
    private func monthTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "LLLL yyyy" // февраль 2026
        return df.string(from: date).capitalized
    }
    
    private func dayTitle(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "EEEE, d MMMM"
        return df.string(from: date)
    }
    
    private func monthDays(for anchor: Date) -> [Date] {
        let cal = Calendar.current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: anchor))!
        let range = cal.range(of: .day, in: .month, for: startOfMonth)!
        
        // сколько пустых ячеек перед 1 числом (чтобы начиналось с понедельника)
        let weekday = cal.component(.weekday, from: startOfMonth) // 1=Sunday
        let mondayBased = (weekday + 5) % 7 // 0=Mon, 6=Sun
        let prefix = mondayBased
        
        var days: [Date] = []
        
        // добавим дни предыдущего месяца как "заглушки" (чтобы сетка ровная)
        if prefix > 0 {
            for i in stride(from: prefix, to: 0, by: -1) {
                days.append(cal.date(byAdding: .day, value: -i, to: startOfMonth)!)
            }
        }
        
        // дни текущего месяца
        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: startOfMonth)!)
        }
        
        // добиваем до кратности 7 (полные недели)
        while days.count % 7 != 0 {
            let last = days.last!
            days.append(cal.date(byAdding: .day, value: 1, to: last)!)
        }
        
        return days
    }
    
    private func tasksForDay(_ day: Date) -> [TaskModel] {
        let cal = Calendar.current
        return tasks.filter { t in
            guard let d = t.dueDate else { return false }
            return cal.isDate(d, inSameDayAs: day)
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    
    private func hasTasks(on day: Date) -> Bool {
        !tasksForDay(day).isEmpty
    }
    
    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let cal = Calendar.current
        let isCurrentMonth = cal.component(.month, from: day) == cal.component(.month, from: monthAnchor)
        let isSelected = selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false
        let isToday = cal.isDateInToday(day)
        
        Button {
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
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isToday ? Color.accentColor.opacity(0.35) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
}

#Preview {
    NavigationStack {
        UpcomingView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}
