//
//  TaskStore.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import Foundation
internal import Combine
@MainActor

final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    
    func add(_ newTasks: [TaskItem]) {
        tasks.append(contentsOf: newTasks)
    }
     
    func toggle(_ id: UUID){
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
             tasks[i].isDone.toggle()
        
    }
    
    func replaceAll(_ newTask: [TaskItem]){
        tasks = newTask
    }
    
}
