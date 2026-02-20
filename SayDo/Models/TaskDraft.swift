//
//  TaskDraft.swift
//  SayDo
//
//  Created by Denys Ilchenko on 18.02.26.
//

import Foundation


struct TaskDraft: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date?
    
    var reminderEnabled: Bool = false
    var reminderMinutesBefore: Int = 10
}
