//
//  TaskListView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI

struct TaskListView: View {
    @State var tasks: [TaskItem]
    var body: some View {
        List {
            ForEach($tasks){ $task in
                HStack{
                    Button{
                        task.isDone.toggle()
                    } label: {
                 Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    }
                    .buttonStyle(.plain)
                    Text(task.title)
                }
            }
        }
        .navigationTitle(Text("Список задач"))
    }
       
}

#Preview {
    TaskListView(tasks: [
        TaskItem(title: "Купить молоко"),
        TaskItem(title: "Позвонить Ване"),
        TaskItem(title: "Написать клиенту")
    ])
}
