//
//  CaptureView.swift
//  SayDo
//
//  Updated: Dark + AppBackground style
//

import SwiftUI
import SwiftData


struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = CaptureViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    private var ui: UI { UI(isDark: themeManager.theme == .dark) }

    var body: some View { content }

    private var content: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                statusCard
                actions
                Spacer(minLength: 80)
            }
            .padding()

            FloatingMicButton(isRecording: vm.isRecording) {
                vm.isRecording ? vm.stop() : vm.start()
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
        .task { await vm.requestPermission() }
        .fullScreenCover(isPresented: reviewBinding) { reviewScreen }
        .overlay {
            if isProcessing {
                ProgressOverlay(text: "Обрабатываю…", isDark: ui.isDark)
            }
            
        }
        .navigationTitle("Capture")
    }

    
    private struct ProgressOverlay: View {
        let text: String
        let isDark: Bool

        private var dim: Color { isDark ? Color.black.opacity(0.40) : Color.black.opacity(0.12) }
        private var labelColor: Color { isDark ? .white.opacity(0.85) : .primary }
        private var stroke: Color { isDark ? .white.opacity(0.10) : .black.opacity(0.06) }
        private var material: AnyShapeStyle { isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial) }

        var body: some View {
            ZStack {
                dim.ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(labelColor)
                }
                .padding(18)
                .background(material)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(stroke, lineWidth: 1)
                )
            }
        }
    }
   
    
    // MARK: - Status card

    private var statusCard: some View {
        Card(ui: ui) {
            Text(phaseTitle)
                .font(.title3)
                .foregroundStyle(ui.primaryText)

            if let subtitle = phaseSubtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(ui.secondaryText)
            }

            if case .error(let message) = vm.phase {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var phaseTitle: String {
        switch vm.phase {
        case .idle: return "Нажми на микрофон и говори."
        case .listening: return "Слушаю…"
        case .processing: return "Обрабатываю…"
        case .review(let drafts): return "Найдено задач: \(drafts.count)"
        case .error: return "Не получилось 😅"
        }
    }

    private var phaseSubtitle: String? {
        switch vm.phase {
        case .idle:
            return "Я превращу речь в задачи и покажу их на экране подтверждения."
        case .listening:
            return "Говори спокойно. После остановки я покажу готовые задачи."
        case .processing:
            return "Секунду — выделяю задачи и даты."
        case .review:
            return "Открой экран подтверждения."
        case .error:
            return nil
        }
    }

    // MARK: - Actions

    private var actions: some View {
        Group {
            if case .error = vm.phase {
                HStack(spacing: 12) {
                    Button { vm.reset() } label: {
                        Label("Сбросить", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        vm.reset()
                        vm.start()
                    } label: {
                        Label("Ещё раз", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Review Screen

    @ViewBuilder
    private var reviewScreen: some View {
        if case .review(let drafts) = vm.phase {
            ConfirmTasksView(
                drafts: drafts,
                onCancel: { vm.cancelReview() },
                onDelete: { vm.deleteDraft($0) },
                onUpdate: { vm.updateDraft($0) },
                onConfirm: { confirmDrafts() }
            )
        }
    }

    private func confirmDrafts() {
        let models = vm.confirmedTasks()

        for m in models {
            if m.reminderEnabled {
                m.notificationID = m.notificationID ?? UUID().uuidString
            } else {
                m.notificationID = nil
            }
            context.insert(m)
        }

        do { try context.save() } catch { print("❌ Save error:", error) }

        Task {
            for m in models { await scheduleIfNeeded(task: m) }
        }

        vm.reset()
    }

    // MARK: - Notifications

    private func scheduleIfNeeded(task: TaskModel) async {
        guard let id = task.notificationID else { return }

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
        guard fireDate > Date() else {
            await NotificationService.shared.cancel(id: id)
            return
        }

        await NotificationService.shared.schedule(id: id, title: task.title, fireDate: fireDate)
    }

    // MARK: - Helpers

    private var isProcessing: Bool {
        if case .processing = vm.phase { return true }
        return false
    }

    private var reviewBinding: Binding<Bool> {
        Binding(
            get: { if case .review = vm.phase { return true } else { return false } },
            set: { newValue in if !newValue { vm.cancelReview() } }
        )
    }
}

// MARK: - UI tokens

private struct UI {
    let isDark: Bool
    var primaryText: Color { isDark ? .white : .primary }
    var secondaryText: Color { isDark ? .white.opacity(0.75) : .secondary }
    var stroke: Color { isDark ? .white.opacity(0.10) : .black.opacity(0.06) }
    var material: AnyShapeStyle { isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial) }
}

// MARK: - Card

private struct Card<Content: View>: View {
    let ui: UI
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ui.material)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(ui.stroke, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
    .environmentObject(ThemeManager()) 
}
