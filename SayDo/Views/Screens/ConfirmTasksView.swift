import SwiftUI

struct ConfirmTasksView: View {
    // вход
    let drafts: [TaskDraft]
    let onCancel: () -> Void
    let onDelete: (TaskDraft) -> Void
    let onUpdate: (TaskDraft) -> Void
    let onConfirm: () -> Void

    // локальная копия, чтобы UI сразу обновлялся
    @State private var localDrafts: [TaskDraft] = []

    @State private var bulkReminderEnabled: Bool = false
    @State private var bulkMinutes: Int = 10
    @State private var addToCalendar: Bool = false

    @State private var showCalendarDeniedAlert: Bool = false
    @State private var calendarErrorMessage: String? = nil

    private let minuteOptions = [5, 10, 15, 30, 60]

    // MARK: - Grouping

    private var grouped: [(title: String, items: [TaskDraft])] {
        let cal = Calendar.current
        let now = Date()

        func sectionTitle(for date: Date?) -> String {
            guard let d = date else { return "Без даты" }
            if cal.isDateInToday(d) { return "Сегодня" }
            if cal.isDateInTomorrow(d) { return "Завтра" }
            if let weekEnd = cal.date(byAdding: .day, value: 7, to: now),
               d < weekEnd { return "На этой неделе" }
            return "Позже"
        }

        let dict = Dictionary(grouping: localDrafts) { sectionTitle(for: $0.dueDate) }
        let order = ["Сегодня", "Завтра", "На этой неделе", "Позже", "Без даты"]

        return order.compactMap { key in
            guard let items = dict[key] else { return nil }
            let sorted = items.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (a?, b?): return a < b
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return $0.title < $1.title
                }
            }
            return (key, sorted)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Найдено задач: \(localDrafts.count)")
                        .foregroundStyle(.primary)
                }

                Section {
                    Toggle("Добавить в календарь", isOn: $addToCalendar)
                        .tint(.accentColor)
                } footer: {
                    Text("В календарь добавляются только задачи с датой.")
                }

                Section("Напоминания") {
                    Toggle("Напоминать всем", isOn: $bulkReminderEnabled)

                    Picker("За сколько минут", selection: $bulkMinutes) {
                        ForEach(minuteOptions, id: \.self) { m in
                            Text("\(m) мин").tag(m)
                        }
                    }
                    .disabled(!bulkReminderEnabled)

                    Button("Применить ко всем задачам") {
                        applyBulkReminder()
                    }
                    .disabled(localDrafts.isEmpty)
                }

                ForEach(grouped, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { draft in
                            NavigationLink {
                                EditDraftView(draft: draft, onSave: updateDraft)
                            } label: {
                                DraftRow(draft: draft)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    deleteDraft(draft)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .cardListStyle()
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)

            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { confirmTapped() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Нет доступа к календарю", isPresented: $showCalendarDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Разреши доступ к календарю в настройках, чтобы SayDo мог добавлять события.")
            }
            .alert("Ошибка календаря", isPresented: Binding(
                get: { calendarErrorMessage != nil },
                set: { if !$0 { calendarErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(calendarErrorMessage ?? "")
            }
            .onAppear {
                // важно: берём входные drafts в локальное состояние, чтобы UI обновлялся
                localDrafts = drafts
            }
        }
    }

    // MARK: - Actions (локальные)

    private func updateDraft(_ draft: TaskDraft) {
        if let idx = localDrafts.firstIndex(where: { $0.id == draft.id }) {
            localDrafts[idx] = draft
        }
        onUpdate(draft)
    }

    private func deleteDraft(_ draft: TaskDraft) {
        localDrafts.removeAll { $0.id == draft.id }
        onDelete(draft)
    }

    private func applyBulkReminder() {
        for d in localDrafts {
            var updated = d

            // без даты напоминание невозможно — выключаем
            if updated.dueDate == nil {
                updated.reminderEnabled = false
            } else {
                updated.reminderEnabled = bulkReminderEnabled
                updated.reminderMinutesBefore = bulkMinutes
            }

            updateDraft(updated) // 🔥 обновляем локально + отправляем наружу
        }
    }

    // MARK: - Confirm

    private func confirmTapped() {
        Task {
            // Если календарь не нужен — просто подтверждаем
            guard addToCalendar else {
                onConfirm()
                return
            }

            // Просим доступ (только чтобы показать алерт заранее)
            let auth = await CalendarService.shared.requestAccessIfNeeded()
            guard auth == .authorized else {
                showCalendarDeniedAlert = true
                // всё равно добавим задачи в приложение
                onConfirm()
                return
            }

            // ⚠️ ВАЖНО: НЕ создаём события по drafts здесь,
            // иначе будут дубли (потому что потом TaskModel снова синкнется).
            // События создаём только там, где уже есть TaskModel + можно записать calendarEventID.
            onConfirm()
        }
    }
}

// MARK: - Row

private struct DraftRow: View {
    let draft: TaskDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(draft.title.isEmpty ? "Без названия" : draft.title)
                    .lineLimit(2)

                Spacer()

                if draft.reminderEnabled, draft.dueDate != nil {
                    Text("⏰ \(draft.reminderMinutesBefore) мин")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            if let d = draft.dueDate {
                Text(d.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Без даты")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit screen

private struct EditDraftView: View {
    @Environment(\.dismiss) private var dismiss

    @State var draft: TaskDraft
    let onSave: (TaskDraft) -> Void

    private let minuteOptions = [5, 10, 15, 30, 60]

    var body: some View {
        Form {
            Section("Задача") {
                TextField("Название", text: $draft.title)
            }

            Section("Дата") {
                Toggle(
                    "Есть дата",
                    isOn: Binding(
                        get: { draft.dueDate != nil },
                        set: { hasDate in
                            if hasDate {
                                draft.dueDate = draft.dueDate ?? Date()
                            } else {
                                draft.dueDate = nil
                                draft.reminderEnabled = false
                            }
                        }
                    )
                )

                if let date = draft.dueDate {
                    DatePicker(
                        "Когда",
                        selection: Binding(
                            get: { date },
                            set: { draft.dueDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section("Напоминание") {
                Toggle(
                    "Напомнить",
                    isOn: Binding(
                        get: { draft.reminderEnabled && draft.dueDate != nil },
                        set: { on in
                            if draft.dueDate == nil {
                                draft.reminderEnabled = false
                            } else {
                                draft.reminderEnabled = on
                            }
                        }
                    )
                )
                .disabled(draft.dueDate == nil)

                if draft.reminderEnabled, draft.dueDate != nil {
                    Picker("За сколько минут", selection: $draft.reminderMinutesBefore) {
                        ForEach(minuteOptions, id: \.self) { m in
                            Text("\(m) мин").tag(m)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)

        .navigationTitle("Редактировать")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    onSave(draft)
                    dismiss()
                }
            }
        }
    }
}
