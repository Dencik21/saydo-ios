//
//  ThemeManager.swift
//  SayDo
//
//  Created by Denys Ilchenko on 24.02.26.
//

import Foundation
import SwiftUI
import Combine

import SwiftUI

final class ThemeManager: ObservableObject {
    @AppStorage("appTheme") private var storedTheme: String = AppTheme.dark.rawValue

    @Published var theme: AppTheme = .dark {
        didSet {
            storedTheme = theme.rawValue
            applyAppearance()     // ✅ важно
        }
    }

    init() {
        theme = AppTheme(rawValue: storedTheme) ?? .dark
        applyAppearance()
    }

    func toggle() {
        theme = (theme == .dark) ? .light : .dark
    }

    // MARK: - UIKit appearance (TabBar / NavBar)

    func applyAppearance() {
        let isDark = (theme == .dark)

        // --- TabBar ---
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()

        // приглушённый фон (не белый!)
        tab.backgroundColor = isDark
        ? UIColor.black.withAlphaComponent(0.85)
        : UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 0.92)

        tab.shadowColor = UIColor.clear

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // --- NavigationBar ---
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = tab.backgroundColor
        nav.shadowColor = UIColor.clear

        nav.titleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]
        nav.largeTitleTextAttributes = [.foregroundColor: isDark ? UIColor.white : UIColor.black]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
