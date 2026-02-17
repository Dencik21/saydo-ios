//
//  TaskItem.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import Foundation

struct TaskItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    var isDone: Bool = false
}
                
