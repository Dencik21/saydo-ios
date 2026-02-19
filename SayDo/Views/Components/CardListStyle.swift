//
//  CardListStyle.swift
//  SayDo
//
//  Created by Denys Ilchenko on 19.02.26.
//


import SwiftUI

struct CardListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
    }
}

extension View {
    func cardListStyle() -> some View {
        modifier(CardListStyle())
    }
}
