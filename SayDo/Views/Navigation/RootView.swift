//
//  RootView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                InboxView()
            }
            .tabItem { Label("Inbox", systemImage: "tray") }

            NavigationStack {
                RecordView()
            }
            .tabItem { Label("Record", systemImage: "mic") }

            NavigationStack {
                UpcomingView()
            }
            .tabItem { Label("Plan", systemImage: "calendar") }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(TaskStore())
}
