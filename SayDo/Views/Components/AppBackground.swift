//
//  AppBackground.swift
//  SayDo
//
//  Created by Denys Ilchenko on 23.02.26.
//

import SwiftUI

struct AppBackground<Content: View>: View {
    let content: Content
    @EnvironmentObject private var themeManager: ThemeManager

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var lineColors: [Color] {
        switch themeManager.theme {
        case .dark:
            return [
                Color(red: 233/255, green: 71/255, blue: 245/255),
                Color(red: 47/255,  green: 75/255,  blue: 162/255)
            ]


        case .light:
            return [
                Color(red: 0.25, green: 0.45, blue: 0.95).opacity(0.16),
                Color(red: 0.75, green: 0.35, blue: 0.95).opacity(0.12)
            ]
        }
    }

    private var baseColor: Color {
        switch themeManager.theme {
        case .dark:
            return .black
        case .light:
            return Color(red: 0.985, green: 0.985, blue: 0.99) // почти белый, очень чистый
        }
    }

    var body: some View {
        ZStack {
            FloatingLinesBackground(
                enabledWaves: [.top, .middle, .bottom],
                lineCount: 5,
                lineSpacing: 14,
                animationSpeed: 1.0,
                interactive: false,
                parallax: false,
                colors: lineColors,
                baseBackground: baseColor,
                isDarkBase: themeManager.theme == .dark
            )
            .ignoresSafeArea()

            content
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .automatic)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
    }
}

#Preview {
    AppBackground { Text("Preview") }
        .environmentObject(ThemeManager())
}
