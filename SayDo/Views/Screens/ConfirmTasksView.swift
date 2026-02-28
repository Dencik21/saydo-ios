//
//  ConfirmTasksView.swift
//  SayDo
//
//  Clean version: passes addToCalendar flag outward
//

import SwiftUI
import MapKit

struct ConfirmTasksView: View {

    // MARK: - Input

    let drafts: [TaskDraft]
    let onCancel: () -> Void
    let onDelete: (TaskDraft) -> Void
    let onUpdate: (TaskDraft) -> Void
    let onConfirm: (_ addToCalendar: Bool) -> Void

    // MARK: - Local state

    @State private var localDrafts: [TaskDraft] = []
    @State private var bulkReminderEnabled: Bool = false
    @State private var bulkMinutes: Int = 10
    @State private var addToCalendar: Bool = false

    private let minuteOptions = [5, 10, 15, 30, 60]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {

                Section {
                    Text("Найдено задач: \(localDrafts.count)")
                }

                Section {
                    Toggle("Добавить в календарь", isOn: $addToCalendar)
                } footer: {
                    Text("В календарь добавляются только задачи с датой.")
                }

                Section("Напоминания") {
                    Toggle("Напоминать всем", isOn: $bulkReminderEnabled)

                    Picker("За сколько минут", selection: $bulkMinutes) {
                        ForEach(minuteOptions, id: \.self) {
                            Text("\($0) мин").tag($0)
                        }
                    }
                    .disabled(!bulkReminderEnabled)

                    Button("Применить ко всем задачам") {
                        applyBulkReminder()
                    }
                    .disabled(localDrafts.isEmpty)
                }

                ForEach(localDrafts) { draft in
                    NavigationLink {
                        EditDraftView(draft: draft, onSave: updateDraft)
                    } label: {
                        DraftRow(draft: draft)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            deleteDraft(draft)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        onConfirm(addToCalendar)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                localDrafts = drafts
            }
        }
    }

    // MARK: - Update / Delete

    private func updateDraft(_ draft: TaskDraft) {
        if let index = localDrafts.firstIndex(where: { $0.id == draft.id }) {
            localDrafts[index] = draft
        }
        onUpdate(draft)
    }

    private func deleteDraft(_ draft: TaskDraft) {
        localDrafts.removeAll { $0.id == draft.id }
        onDelete(draft)
    }

    private func applyBulkReminder() {
        for i in localDrafts.indices {
            if localDrafts[i].dueDate != nil {
                localDrafts[i].reminderEnabled = bulkReminderEnabled
                localDrafts[i].reminderMinutesBefore = bulkMinutes
                onUpdate(localDrafts[i])
            }
        }
    }
}

// MARK: - Draft Row

private struct DraftRow: View {

    let draft: TaskDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Text(draft.title.isEmpty ? "Без названия" : draft.title)
                    .lineLimit(2)

                Spacer()

                if draft.reminderEnabled, draft.dueDate != nil {
                    Text("⏰ \(draft.reminderMinutesBefore) мин")
                        .font(.caption2)
                        .padding(6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }

            if let date = draft.dueDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Без даты")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let address = draft.address, !address.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit View

private struct EditDraftView: View {

    @Environment(\.dismiss) private var dismiss
    @State var draft: TaskDraft
    let onSave: (TaskDraft) -> Void

    var body: some View {
        Form {

            Section("Задача") {
                TextField("Название", text: $draft.title)
            }

            Section("Место") {
                TextField("Адрес", text: Binding(
                    get: { draft.address ?? "" },
                    set: { draft.address = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Дата") {
                Toggle("Есть дата", isOn: Binding(
                    get: { draft.dueDate != nil },
                    set: {
                        draft.dueDate = $0 ? Date() : nil
                        if !$0 { draft.reminderEnabled = false }
                    }
                ))

                if let date = draft.dueDate {
                    DatePicker("Когда", selection: Binding(
                        get: { date },
                        set: { draft.dueDate = $0 }
                    ))
                }
            }

            Section("Напоминание") {
                Toggle("Напомнить", isOn: $draft.reminderEnabled)
                    .disabled(draft.dueDate == nil)
            }
        }
        .navigationTitle("Редактировать")
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

// MARK: - Preview

#Preview {
    ConfirmTasksView(
        drafts: [],
        onCancel: {},
        onDelete: { _ in },
        onUpdate: { _ in },
        onConfirm: { _ in }
    )
}
