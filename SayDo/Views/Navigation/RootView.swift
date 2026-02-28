import SwiftUI

struct RootView: View {

    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Group {
            if hasOnboarded {
                mainTabs
            } else {
                NavigationStack {
                    WelcomeView()
                        .toolbar {
                            themeToolbar
                        }
                }
            }
        }
    }

    // MARK: - Tabs

    private var mainTabs: some View {
        TabView {
            navRoot(AppBackground { InboxView() })
                .tabItem { Label("Inbox", systemImage: "tray") }

            navRoot(AppBackground { TodayView() })
                .tabItem { Label("Today", systemImage: "sun.max") }

            navRoot(AppBackground { UpcomingView() })
                .tabItem { Label("Upcoming", systemImage: "calendar") }

            navRoot(AppBackground { CaptureView() })
                .tabItem { Label("Capture", systemImage: "mic") }

            #if DEBUG
            #if targetEnvironment(simulator)
            navRoot(AppBackground { DebugAllTasksView() })
                .tabItem { Label("Debug", systemImage: "ladybug") }
            #endif
            #endif
        }
    }
    // MARK: - Navigation Wrapper (чтобы не копировать toolbar везде)

    private func navRoot<Content: View>(_ content: Content) -> some View {
        NavigationStack {
            content
                .toolbar { themeToolbar }
        }
    }
    // MARK: - Theme Button

    private var themeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                toggleTheme()
            } label: {
                Image(systemName: themeManager.theme.iconName)
            }
        }
    }

    // MARK: - Theme Logic

    private func toggleTheme() {
            themeManager.toggle()
    }
}

#Preview {
    RootView()
        .environmentObject(ThemeManager())
}
