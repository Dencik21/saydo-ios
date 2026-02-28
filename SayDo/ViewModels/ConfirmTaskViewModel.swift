//
//  ConfirmTasksViewModel.swift
//  SayDo
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ConfirmTasksViewModel: ObservableObject {

    // MARK: - Output for UI

    @Published private(set) var drafts: [TaskDraft] = []

    @Published var bulkReminderEnabled: Bool = false
    @Published var bulkMinutes: Int = 10
    @Published var addToCalendar: Bool = false

    let minuteOptions: [Int] = [5, 10, 15, 30, 60]

    // MARK: - External callbacks

    private let onCancel: () -> Void
    private let onDelete: (TaskDraft) -> Void
    private let onUpdate: (TaskDraft) -> Void
    private let onConfirm: (_ addToCalendar: Bool) -> Void

    // MARK: - Init

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
    }

    // MARK: - Inputs from parent

    func setDrafts(_ newDrafts: [TaskDraft]) {
        drafts = newDrafts
    }

    // MARK: - User actions

    func cancel() {
        onCancel()
    }

    func confirm() {
        onConfirm(addToCalendar)
    }

    func updateDraft(_ draft: TaskDraft) {
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = draft
        }
        onUpdate(draft)
    }

    func deleteDraft(_ draft: TaskDraft) {
        drafts.removeAll { $0.id == draft.id }
        onDelete(draft)
    }

    func applyBulkReminder() {
        for i in drafts.indices {
            guard drafts[i].dueDate != nil else { continue }

            drafts[i].reminderEnabled = bulkReminderEnabled

            if bulkReminderEnabled {
                drafts[i].reminderMinutesBefore = bulkMinutes
            }

            onUpdate(drafts[i])
        }
    }
}
