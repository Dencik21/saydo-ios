

//
//  CaptureView.swift
//  SayDo
//

import SwiftUI
import SwiftData

struct CaptureView: View {

    @Environment(\.modelContext) private var context
    @StateObject private var vm = CaptureViewModel()
    @EnvironmentObject private var themeManager: ThemeManager

    private var ui: UI { UI(isDark: themeManager.theme == .dark) }

    var body: some View {
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
}

//
// MARK: - REVIEW
//

private extension CaptureView {

    @ViewBuilder
    var reviewScreen: some View {
        if case .review(let drafts) = vm.phase {
            ConfirmTasksView(
                drafts: drafts,
                onCancel: { vm.cancelReview() },
                onDelete: { vm.deleteDraft($0) },
                onUpdate: { vm.updateDraft($0) },
                onConfirm: { addToCalendar in
                    confirmDrafts(addToCalendar: addToCalendar)
                }
            )
        }
    }

    func confirmDrafts(addToCalendar: Bool) {
        let models = vm.confirmedTasks()

        Task {
            await TaskSyncService.shared.persistAndSync(
                tasks: models,
                in: context,
                addToCalendar: addToCalendar
            )

            // UI reset только после всех операций
            await MainActor.run {
                vm.reset()
            }
        }
    }
}

//
// MARK: - STATUS UI
//

private extension CaptureView {

    var statusCard: some View {
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

    var phaseTitle: String {
        switch vm.phase {
        case .idle: return "Нажми на микрофон и говори."
        case .listening: return "Слушаю…"
        case .processing: return "Обрабатываю…"
        case .review(let drafts): return "Найдено задач: \(drafts.count)"
        case .error: return "Ошибка 😅"
        }
    }

    var phaseSubtitle: String? {
        switch vm.phase {
        case .idle:
            return "Я превращу речь в задачи."
        case .listening:
            return "Говори спокойно."
        case .processing:
            return "Выделяю задачи и даты."
        case .review:
            return "Подтверди задачи."
        case .error:
            return nil
        }
    }

    var actions: some View {
        Group {
            if case .error = vm.phase {
                HStack(spacing: 12) {

                    Button("Сбросить") {
                        vm.reset()
                    }
                    .buttonStyle(.bordered)

                    Button("Ещё раз") {
                        vm.reset()
                        vm.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    var isProcessing: Bool {
        if case .processing = vm.phase { return true }
        return false
    }

    var reviewBinding: Binding<Bool> {
        Binding(
            get: { if case .review = vm.phase { return true } else { return false } },
            set: { if !$0 { vm.cancelReview() } }
        )
    }
}

//
// MARK: - UI SUPPORT
//

private struct UI {
    let isDark: Bool
    var primaryText: Color { isDark ? .white : .primary }
    var secondaryText: Color { isDark ? .white.opacity(0.7) : .secondary }
    var stroke: Color { isDark ? .white.opacity(0.1) : .black.opacity(0.05) }
    var material: AnyShapeStyle { isDark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial) }
}

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

private struct ProgressOverlay: View {
    let text: String
    let isDark: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(isDark ? 0.4 : 0.15)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text(text)
                    .font(.footnote)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
    .environmentObject(ThemeManager())
}
