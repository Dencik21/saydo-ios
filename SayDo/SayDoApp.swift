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
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: TaskModel.self)
    }
}


