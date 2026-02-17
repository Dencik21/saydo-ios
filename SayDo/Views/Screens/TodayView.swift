//
//  TodayView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//


import SwiftUI

struct TodayView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Today")
                .font(.largeTitle.bold())
            Text("Здесь будут задачи на сегодня.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Today")
    }
}

#Preview {
    TodayView()
}
