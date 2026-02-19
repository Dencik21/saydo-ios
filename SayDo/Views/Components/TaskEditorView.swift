//
//  TaskEditorView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//


import SwiftUI
import SwiftData
import UserNotifications

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let task: TaskModel

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    
    @State private var reminderEnabled: Bool = false
    @State private var reminderMinutesBefore: Int = 10


    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    TextField("Название", text: $title)
                }

                Section("Дата") {
                    Toggle("Есть дата", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("Когда", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    } else {
                        Text("Без даты → Inbox")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Удалить", role: .destructive) {
                        context.delete(task)
                        try? context.save()
                        dismiss()
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

            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        task.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        task.dueDate = hasDueDate ? dueDate : nil

                        task.reminderEnabled = hasDueDate ? reminderEnabled : false
                        task.reminderMinutesBefore = reminderMinutesBefore

                        if task.notificationID == nil {
                            task.notificationID = UUID().uuidString
                        }

                        try? context.save()

                        Task {
                            await syncNotification(for: task)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

            }
            .onAppear {
                reminderEnabled = task.reminderEnabled
                reminderMinutesBefore = task.reminderMinutesBefore
                title = task.title
                if let d = task.dueDate {
                    hasDueDate = true
                    dueDate = d
                } else {
                    hasDueDate = false
                    dueDate = Date()
                }
                if task.dueDate == nil {
                    reminderEnabled = false
                }

            }
        }
    }
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

}
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
