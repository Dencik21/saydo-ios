//
//  SayDoApp.swift
//  SayDo
//
//  Created by Denys Ilchenko on 16.02.26.
//

import SwiftUI
import SwiftData

@main
struct SayDoApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.theme.colorScheme)
        }
        .modelContainer(for: TaskModel.self)
    }
}
