//
//  WelcomeView.swift
//  SayDo
//
//  Created by Denys Ilchenko on 24.02.26.
//

import SwiftUI


struct WelcomeView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }
    private var titleColor: Color { isDark ? .white : .black }
    private var subtitleColor: Color { isDark ? .white.opacity(0.85) : .black.opacity(0.75) }
    private var buttonTextColor: Color { isDark ? .white : .black }

    var body: some View {
        AppBackground {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Text("SayDo")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(titleColor)              // ✅ стабильно

                    Text("Говори. Планируй. Действуй.")
                        .font(.headline)
                        .foregroundStyle(subtitleColor)           // ✅ стабильно
                }

                VStack(spacing: 16) {
                    Button {
                        withAnimation(.spring()) { hasOnboarded = true }
                    } label: {
                        Text("Начать")
                            .font(.headline)
                            .foregroundStyle(buttonTextColor)     // ✅ не синий
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isDark ? .white.opacity(0.16) : .black.opacity(0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain) // ✅ убираем системный tint/синий
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)

    WelcomeView()
        .environmentObject(ThemeManager())
        .preferredColorScheme(.light)
}
