//
//  CardRowStyle.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//

import SwiftUI

struct CardRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.vertical, 4)
    }
}

extension View {
    func cardRowStyle() -> some View {
        modifier(CardRowStyle())
    }
}
