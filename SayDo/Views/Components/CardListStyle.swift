//
//  CardListStyle.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//


import SwiftUI

struct CardListStyle: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager

    private var isDark: Bool { themeManager.theme == .dark }

    private var overlayTint: Color {
        isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)        // убираем системный фон
                          
    }
}

extension View {
    func cardListStyle() -> some View {
        modifier(CardListStyle())
    }
}
