import SwiftUI
import SwiftData

struct CaptureView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = CaptureViewModel()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                header
                contentCard
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

        .fullScreenCover(isPresented: reviewBinding) {
            if case .review(let drafts) = vm.phase {
                ConfirmTasksView(
                    drafts: drafts,
                    onCancel: { vm.cancelReview() },
                    onDelete: { vm.deleteDraft($0) },
                    onUpdate: { vm.updateDraft($0) },
                    onConfirm: {
                        // ✅ vm.confirmedTasks() уже возвращает [TaskModel]
                        let models = vm.confirmedTasks()

                        // Вставляем модели в SwiftData
                        for m in models {
                            context.insert(m)
                        }

                        do {
                            try context.save()
                            // print("✅ Saved:", models.count)
                        } catch {
                            print("❌ Save error:", error)
                        }

                        vm.reset()
                    }
                )
            }
        }
        .overlay {
            if isProcessing {
                ProgressOverlay(text: "Обрабатываю…")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Capture")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Main card

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch vm.phase {
            case .idle:
                Text("Нажми на микрофон и говори.")
                    .font(.title3)
                Text("Я превращу речь в задачи и покажу их на экране подтверждения.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .listening:
                Text("Слушаю…")
                    .font(.title3)
                Text("Говори спокойно. После остановки я покажу готовые задачи.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .processing:
                Text("Обрабатываю…")
                    .font(.title3)
                Text("Секунду — выделяю задачи и даты.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .review(let drafts):
                Text("Найдено задач: \(drafts.count)")
                    .font(.title3)
                Text("Открой экран подтверждения.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .error(let message):
                Text("Не получилось 😅")
                    .font(.title3)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private var actions: some View {
        Group {
            switch vm.phase {
            case .idle, .listening, .processing, .review:
                EmptyView()

            case .error:
                HStack(spacing: 12) {
                    Button {
                        vm.reset()
                    } label: {
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

    // MARK: - Helpers

    private var isProcessing: Bool {
        if case .processing = vm.phase { return true }
        return false
    }

    private var reviewBinding: Binding<Bool> {
        Binding(
            get: {
                if case .review = vm.phase { return true }
                return false
            },
            set: { newValue in
                if !newValue { vm.cancelReview() }
            }
        )
    }
}

// MARK: - Overlay

private struct ProgressOverlay: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

#Preview {
    NavigationStack {
        CaptureView()
    }
    .modelContainer(for: TaskModel.self, inMemory: true)
}
