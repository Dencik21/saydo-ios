//
//  FloatingMicButton.swift
//  SayDo
//
//  Created by Denys Ilchenko on 17.02.26.
//

import SwiftUI

struct FloatingMicButton: View {
    let isRecording: Bool
    let action: () -> Void
    @State private var pulse = false
    
    var body: some View {
        Button(action: action){
            Image(systemName:  isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(
                    Circle().fill(isRecording ? .red : .blue)
                )
                .overlay(
                    Circle()
                        .stroke(isRecording ? .red.opacity(0.35) : .clear, lineWidth: 10)
                        .scaleEffect(pulse ? 1.0 : 1.25)
                        .opacity(pulse ? 0.0 : 1.0)
                )
                .shadow(radius: 10, y: 6)
        }
        .buttonStyle(.plain)
        .onAppear{syncPlus(isRecording)}
        .onChange(of: isRecording) { _, newValue in
            syncPlus(newValue)
        }
    }
    
    private func syncPlus(_ recording: Bool) {
        if recording {
            pulse = false
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)){
                pulse = true
            }
        } else {
            pulse = false
        }
    }
}

#Preview {
    FloatingMicButton(isRecording: false,
    action: {})
}
