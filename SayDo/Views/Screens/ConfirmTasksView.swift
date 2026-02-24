import SwiftUI

import SwiftUI

struct ConfirmTasksView: View {
    let drafts: [TaskDraft]

    let onCancel: () -> Void
    let onDelete: (TaskDraft) -> Void
    let onUpdate: (TaskDraft) -> Void
    let onConfirm: () -> Void

    @State private var bulkReminderEnabled: Bool = false
    @State private var bulkMinutes: Int = 10

    private let minuteOptions = [5, 10, 15, 30, 60]

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

        let dict = Dictionary(grouping: drafts) { sectionTitle(for: $0.dueDate) }

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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Найдено задач: \(drafts.count)")
                        .foregroundStyle(.primary) // ✅ чёрный/primary, как ты хочешь
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
                    .disabled(drafts.isEmpty)
                }

                ForEach(grouped, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.items) { draft in
                            NavigationLink {
                                EditDraftView(draft: draft, onSave: onUpdate)
                            } label: {
                                DraftRow(draft: draft)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDelete(draft)
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
               
            }
            .cardListStyle() // ✅ вот оно
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .background(Color.clear)
            
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { onConfirm() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func applyBulkReminder() {
        for d in drafts {
            var updated = d
            if updated.dueDate == nil {
                updated.reminderEnabled = false
            } else {
                updated.reminderEnabled = bulkReminderEnabled
                updated.reminderMinutesBefore = bulkMinutes
            }
            onUpdate(updated)
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
        // ✅ ВАЖНО: это должно быть на Form, а не на Section
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))   // ✅ ВОТ ЭТО
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
#Preview("ConfirmTasksView") {
    let cal = Calendar.current
    let now = Date()

    let drafts: [TaskDraft] = [
        TaskDraft(title: "Позвонить врачу", dueDate: now),
        TaskDraft(title: "Купить продукты", dueDate: now),

        TaskDraft(title: "Спортзал (ноги)", dueDate: cal.date(byAdding: .day, value: 1, to: now)),
        TaskDraft(title: "Оплатить счёт", dueDate: cal.date(byAdding: .day, value: 3, to: now)),

        TaskDraft(title: "Записаться на термин", dueDate: cal.date(byAdding: .day, value: 10, to: now)),
        TaskDraft(title: "Ресторан с друзьями", dueDate: nil)
    ]

    return ConfirmTasksView(
        drafts: drafts,
        onCancel: { print("Cancel") },
        onDelete: { draft in print("Delete:", draft.title) },
        onUpdate: { draft in print("Update:", draft.title) },
        onConfirm: { print("Confirm") }
    )
    .environmentObject(ThemeManager())
}
