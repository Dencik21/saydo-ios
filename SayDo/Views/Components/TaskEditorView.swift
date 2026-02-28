//
//  TaskEditorView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//

import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: TaskModel

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    @State private var reminderEnabled: Bool = false
    @State private var reminderMinutesBefore: Int = 10

    @State private var showCalendarDeniedAlert: Bool = false
    @State private var calendarErrorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    TextField("Название", text: $title)
                }

                Section("Дата") {
                    Toggle("Есть дата", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _, newValue in
                            if !newValue {
                                reminderEnabled = false
                            }
                        }

                    if hasDueDate {
                        DatePicker("Когда", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("Без даты → Inbox")
                            .foregroundStyle(.secondary)
                    }
                }

                if hasDueDate {
                    Section("Напоминание") {
                        Toggle("Напоминать", isOn: $reminderEnabled)

                        if reminderEnabled {
                            Picker("За сколько минут", selection: $reminderMinutesBefore) {
                                Text("0 минут").tag(0)
                                Text("5 минут").tag(5)
                                Text("10 минут").tag(10)
                                Text("30 минут").tag(30)
                                Text("60 минут").tag(60)
                            }
                        }
                    }
                }

                Section {
                    Button("Удалить", role: .destructive) {
                        // календарь
                        if let eventID = task.calendarEventID {
                            try? CalendarService.shared.deleteEvent(eventID: eventID)
                            task.calendarEventID = nil
                        }

                        // уведомления
                        if let nid = task.notificationID {
                            Task { await NotificationService.shared.cancel(id: nid) }
                        }

                        // база
                        context.delete(task)
                        try? context.save()

                        dismiss()
                    }
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        applyFieldsToModel()

                        Task {
                            // календарь
                            await syncCalendar(for: task)

                            // база
                            try? context.save()

                            // уведомления
                            await syncNotification(for: task)

                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Нет доступа к календарю", isPresented: $showCalendarDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Разреши доступ к календарю в настройках, чтобы SayDo мог обновлять события.")
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
                loadFromModel()
            }
        }
    }

    // MARK: - Model mapping

    private func loadFromModel() {
        title = task.title

        reminderEnabled = task.reminderEnabled
        reminderMinutesBefore = task.reminderMinutesBefore

        if let d = task.dueDate {
            hasDueDate = true
            dueDate = d
        } else {
            hasDueDate = false
            dueDate = Date()
            reminderEnabled = false
        }
    }

    private func applyFieldsToModel() {
        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        task.dueDate = hasDueDate ? dueDate : nil

        task.reminderEnabled = hasDueDate ? reminderEnabled : false
        task.reminderMinutesBefore = reminderMinutesBefore

        // id для уведомлений: создаём, только если реально включено
        if task.reminderEnabled {
            if task.notificationID == nil {
                task.notificationID = UUID().uuidString
            }
        } else {
            // если выключили — отменим и занулим
            if let nid = task.notificationID {
                Task { await NotificationService.shared.cancel(id: nid) }
            }
            task.notificationID = nil
        }
    }

    // MARK: - Notifications

    private func syncNotification(for task: TaskModel) async {
        guard let id = task.notificationID else { return }

        // если нет даты / напоминание выключено / задача done — отменяем
        guard task.isDone == false,
              task.reminderEnabled,
              let due = task.dueDate
        else {
            await NotificationService.shared.cancel(id: id)
            return
        }

        let ok = await NotificationService.shared.requestAuthIfNeeded()
        guard ok else { return }

        let fireDate = due.addingTimeInterval(TimeInterval(-task.reminderMinutesBefore * 60))

        // не ставим уведомление в прошлое
        guard fireDate > Date() else {
            await NotificationService.shared.cancel(id: id)
            return
        }

        await NotificationService.shared.schedule(id: id, title: task.title, fireDate: fireDate)
    }

    // MARK: - Calendar

    private func syncCalendar(for task: TaskModel) async {

        // Если даты нет → удаляем событие
        guard task.dueDate != nil else {
            if let eventID = task.calendarEventID {
                try? CalendarService.shared.deleteEvent(eventID: eventID)
                task.calendarEventID = nil
            }
            return
        }

        // Просим доступ
        let auth = await CalendarService.shared.requestAccessIfNeeded()
        guard auth == .authorized else {
            showCalendarDeniedAlert = true
            return
        }

        do {
            // ✅ ВАЖНО: taskID нужен для стабильной привязки и предотвращения дублей
            let id = try CalendarService.shared.upsertEvent(
                existingEventID: task.calendarEventID,
                taskID: task.id,
                title: task.title,
                dueDate: task.dueDate,
                address: task.address, // ✅ сюда адрес
                reminderEnabled: task.reminderEnabled,
                reminderMinutesBefore: task.reminderMinutesBefore
            )
            task.calendarEventID = id
        } catch {
            calendarErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(
        for: TaskModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let task = TaskModel(
        title: "Позвонить врачу",
        dueDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date())
    )

    task.reminderEnabled = true
    task.reminderMinutesBefore = 10
    task.notificationID = UUID().uuidString

    context.insert(task)

    return TaskEditorView(task: task)
        .modelContainer(container)
}
