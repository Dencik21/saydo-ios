import SwiftUI



struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { InboxView() }
                .tabItem { Label("Inbox", systemImage: "tray") }

            NavigationStack { TodayView() }
                .tabItem { Label("Today", systemImage: "sun.max") }

            NavigationStack { UpcomingView() }
                .tabItem { Label("Upcoming", systemImage: "calendar") }

            NavigationStack { CaptureView() }
                .tabItem { Label("Capture", systemImage: "mic") }

            // ✅ Временная вкладка для диагностики
            NavigationStack { DebugAllTasksView() }
                .tabItem { Label("Debug", systemImage: "ladybug") }
        }
    }
}


#Preview {
    RootView()
       
}
