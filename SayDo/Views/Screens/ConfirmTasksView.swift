//
//  ConfirmTasksView.swift
//  SayDo
//
//  UI-only version (logic in ViewModel)
//

import SwiftUI

struct ConfirmTasksView: View {

    // MARK: - Input (same as before)

    let drafts: [TaskDraft]
    let onCancel: () -> Void
    let onDelete: (TaskDraft) -> Void
    let onUpdate: (TaskDraft) -> Void
    let onConfirm: (_ addToCalendar: Bool) -> Void

    // MARK: - VM

    @StateObject private var vm: ConfirmTasksViewModel

    init(
        drafts: [TaskDraft],
        onCancel: @escaping () -> Void,
        onDelete: @escaping (TaskDraft) -> Void,
        onUpdate: @escaping (TaskDraft) -> Void,
        onConfirm: @escaping (_ addToCalendar: Bool) -> Void
    ) {
        self.drafts = drafts
        self.onCancel = onCancel
        self.onDelete = onDelete
        self.onUpdate = onUpdate
        self.onConfirm = onConfirm

        _vm = StateObject(wrappedValue: ConfirmTasksViewModel(
            drafts: drafts,
            onCancel: onCancel,
            onDelete: onDelete,
            onUpdate: onUpdate,
            onConfirm: onConfirm
        ))
    }

    var body: some View {
        NavigationStack {
            List {

                Section {
                    Text("Найдено задач: \(vm.drafts.count)")
                }

                Section {
                    Toggle("Добавить в календарь", isOn: $vm.addToCalendar)
                } footer: {
                    Text("В календарь добавляются только задачи с датой.")
                }

                Section("Напоминания") {
                    Toggle("Напоминать всем", isOn: $vm.bulkReminderEnabled)

                    Picker("За сколько минут", selection: $vm.bulkMinutes) {
                        ForEach(vm.minuteOptions, id: \.self) { v in
                            Text("\(v) мин").tag(v)
                        }
                    }
                    .disabled(!vm.bulkReminderEnabled)

                    Button("Применить ко всем задачам") {
                        vm.applyBulkReminder()
                    }
                    .disabled(vm.drafts.isEmpty)
                }

                ForEach(vm.drafts) { draft in
                    NavigationLink {
                        EditDraftView(
                            draft: draft,
                            minuteOptions: vm.minuteOptions,
                            onSave: { vm.updateDraft($0) }
                        )
                    } label: {
                        DraftRow(draft: draft)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            vm.deleteDraft(draft)
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
                    Button("Отмена") { vm.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") { vm.confirm() }
                        .fontWeight(.semibold)
                        .disabled(vm.drafts.isEmpty)
                }
            }
            // если родитель пришлёт новый массив drafts — обновим VM
            .onChange(of: drafts) { _, newValue in
                vm.setDrafts(newValue)
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

// MARK: - Edit View (UI-only; save goes to VM)

private struct EditDraftView: View {

    @Environment(\.dismiss) private var dismiss
    @State var draft: TaskDraft

    let minuteOptions: [Int]
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

                Picker("За сколько минут", selection: $draft.reminderMinutesBefore) {
                    ForEach(minuteOptions, id: \.self) { v in
                        Text("\(v) мин").tag(v)
                    }
                }
                .disabled(draft.dueDate == nil || draft.reminderEnabled == false)
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
