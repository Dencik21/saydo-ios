//
//  AppIconService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 27.02.26.
//

import Foundation
import UIKit



import UIKit

enum AppIconService {

    @MainActor
    static func apply(themeIsDark: Bool) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        let desired: String? = themeIsDark ? "AppIconDark" : nil
        let current = UIApplication.shared.alternateIconName

        guard current != desired else { return }

        UIApplication.shared.setAlternateIconName(desired)
    }
}
