import SwiftUI

struct InboxView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Inbox")
                .font(.largeTitle.bold())
            Text("Здесь будут все задачи.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Inbox")
    }
}
