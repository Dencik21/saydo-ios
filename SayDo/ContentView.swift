//
//  ContentView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 16.02.26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            RecordView()
                .navigationTitle("SayDo")
        }
    }
}

#Preview {
    ContentView()
}
