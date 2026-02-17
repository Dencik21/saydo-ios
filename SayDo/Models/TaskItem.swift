//
//  TaskItem.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import Foundation

struct TaskItem: Identifiable, Hashable {
    var id = UUID()
    let title: String
    var isDone: Bool = false
    var dueDate: Date? = nil
    
    init(id: UUID = UUID(), title: String, isDone: Bool = false, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
    }
}

