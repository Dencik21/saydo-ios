//
//  AppTheme.swift
//  SayDo
//
//  Created by Denys Ilchenko on 24.02.26.
//

import Foundation
import SwiftUI


enum AppTheme: String, CaseIterable {
    case light
    case dark
    
    var colorScheme: ColorScheme? {
        switch self {

        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    var iconName: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
    
}
