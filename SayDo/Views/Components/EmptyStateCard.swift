//
//  EmptyStateCard.swift
//  SayDo
//
//  Created by Denys Ilchenko on 24.02.26.
//

import SwiftUI

struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial) // ✅ на светлом лучше читается, чем ultraThin
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1) // можно сделать адаптивно
        )
    }
}

#Preview {
    EmptyStateCard(title: "", subtitle: "")
}
