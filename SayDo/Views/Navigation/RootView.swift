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
            .tabItem { Label("Inbox", systemImage: "tray.full")}
            
            NavigationStack {
                RecordView()
            }
            .tabItem { Label("Record", systemImage: "mic.fill")}
            NavigationStack {
                TodayView()
            }
            .tabItem { Label("Today", systemImage: "sun.max.fill")}
        }
    }
}

#Preview {
    RootView()
}
