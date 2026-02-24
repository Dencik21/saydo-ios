//
//  FloatingLinesBackground.swift
//  SayDo
//
//  Created by Denys Ilchenko on 23.02.26.
//

import SwiftUI

struct FloatingLinesBackground: View {

    enum Wave: Hashable { case top, middle, bottom }

    // MARK: - Public

    var enabledWaves: Set<Wave> = [.top, .middle, .bottom]

    var lineCount: Int = 6
    var lineSpacing: CGFloat = 12

    var animationSpeed: Double = 1.0

    var interactive: Bool = true
    var parallax: Bool = true

    var bendStrength: CGFloat = 0.30          // 0...1
    var parallaxStrength: CGFloat = 0.14      // 0...0.5

    /// Цвета линий
    var colors: [Color] = [
        Color(red: 233/255, green: 71/255, blue: 245/255),
        Color(red: 47/255,  green: 75/255,  blue: 162/255)
    ]

    /// База фона (для темы)
    var baseBackground: Color = .black
    var isDarkBase: Bool = false

    // MARK: - State

    @State private var touchPoint: CGPoint? = nil
    @State private var touchInfluence: CGFloat = 0

    // MARK: - Derived

    /// Простая эвристика: если фон "тёмный" — используем затемняющие слои,
    /// если "светлый" — используем осветляющие слои
    
     

    // MARK: - Body

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let size = geo.size
                let t = timeline.date.timeIntervalSinceReferenceDate * animationSpeed

                Canvas { ctx, _ in
                    drawBase(ctx: &ctx, size: size)

                    let par = parallaxOffset(in: size)

                    if enabledWaves.contains(.top) {
                        drawWave(
                            ctx: &ctx,
                            size: size,
                            baseY: size.height * 0.26,
                            amplitude: 20,
                            frequency: 2.2,
                            phase: 0.5,
                            time: t,
                            alpha: 0.28,
                            parallax: par,
                            weight: 0.9
                        )
                    }

                    if enabledWaves.contains(.middle) {
                        drawWave(
                            ctx: &ctx,
                            size: size,
                            baseY: size.height * 0.52,
                            amplitude: 28,
                            frequency: 2.0,
                            phase: 1.2,
                            time: t,
                            alpha: 0.34,
                            parallax: par,
                            weight: 1.0
                        )
                    }

                    if enabledWaves.contains(.bottom) {
                        drawWave(
                            ctx: &ctx,
                            size: size,
                            baseY: size.height * 0.78,
                            amplitude: 22,
                            frequency: 2.1,
                            phase: 1.8,
                            time: t,
                            alpha: 0.26,
                            parallax: par,
                            weight: 0.9
                        )
                    }

                    // читабельность
                    if isDarkBase {
                        drawDarkVignette(ctx: &ctx, size: size)
                        drawDarkFog(ctx: &ctx, size: size)
                    } else {
                        drawLightVignette(ctx: &ctx, size: size)
                        drawLightFog(ctx: &ctx, size: size)
                    }
                }
                .contentShape(Rectangle())
                .gesture(interactive ? dragGesture() : nil)
            }
        }
    }

    // MARK: - Base

    private func drawBase(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        // ✅ Важное: используем baseBackground и лёгкий градиент под него
        if isDarkBase {
            let gradient = Gradient(colors: [
                baseBackground.opacity(0.95),
                baseBackground.opacity(1.0),
                Color.black.opacity(1.0)
            ])

            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: rect.origin,
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
        } else {
            let gradient = Gradient(colors: [
                baseBackground.opacity(1.0),
                baseBackground.opacity(0.98),
                baseBackground.opacity(0.96)
            ])

            ctx.fill(
                Path(rect),
                with: .linearGradient(
                    gradient,
                    startPoint: rect.origin,
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
        }
    }

    // MARK: - Readability layers (Dark)

    private func drawDarkVignette(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        let gradient = Gradient(colors: [
            .black.opacity(0.00),
            .black.opacity(0.35),
            .black.opacity(0.65)
        ])

        ctx.fill(
            Path(rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(size.width, size.height) * 0.10,
                endRadius: max(size.width, size.height) * 0.80
            )
        )
    }

    private func drawDarkFog(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        let topFog = Gradient(colors: [
            .black.opacity(0.55),
            .black.opacity(0.00)
        ])

        ctx.fill(
            Path(rect),
            with: .linearGradient(
                topFog,
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.35)
            )
        )

        let bottomFog = Gradient(colors: [
            .black.opacity(0.00),
            .black.opacity(0.45)
        ])

        ctx.fill(
            Path(rect),
            with: .linearGradient(
                bottomFog,
                startPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.65),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }

    // MARK: - Readability layers (Light)

    private func drawLightVignette(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        let gradient = Gradient(colors: [
            .white.opacity(0.00),
            .white.opacity(0.22),
            .white.opacity(0.45)
        ])

        ctx.fill(
            Path(rect),
            with: .radialGradient(
                gradient,
                center: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(size.width, size.height) * 0.12,
                endRadius: max(size.width, size.height) * 0.85
            )
        )
    }

    private func drawLightFog(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)

        let topFog = Gradient(colors: [
            .white.opacity(0.55),
            .white.opacity(0.00)
        ])

        ctx.fill(
            Path(rect),
            with: .linearGradient(
                topFog,
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.35)
            )
        )

        let bottomFog = Gradient(colors: [
            .white.opacity(0.00),
            .white.opacity(0.40)
        ])

        ctx.fill(
            Path(rect),
            with: .linearGradient(
                bottomFog,
                startPoint: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.65),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
    }

    // MARK: - Wave drawing

    private func drawWave(
        ctx: inout GraphicsContext,
        size: CGSize,
        baseY: CGFloat,
        amplitude: CGFloat,
        frequency: Double,
        phase: Double,
        time: Double,
        alpha: Double,
        parallax: CGSize,
        weight: CGFloat
    ) {
        let width = size.width
        let segments = 36
        let dx = width / CGFloat(segments)

        let safeCount = max(0, lineCount)
        let paletteCount = max(1, colors.count)

        for i in 0..<safeCount {
            let c = colors[i % paletteCount]

            let lineAlpha = alpha * (1.0 - Double(i) * 0.05)
            let core = c.opacity(min(0.95, lineAlpha))
            let glow = c.opacity(min(0.70, lineAlpha * 0.85))

            let y0 = baseY + CGFloat(i) * lineSpacing + parallax.height * 40
            let xShift = parallax.width * 40

            var pts: [CGPoint] = []
            pts.reserveCapacity(segments + 1)

            for s in 0...segments {
                let x = CGFloat(s) * dx
                let nx = x / max(width, 1)

                let localFreq = frequency + Double(i) * 0.12
                let ySin = sin(nx * .pi * localFreq + time * 0.65 + phase)

                var y = y0 + CGFloat(ySin) * amplitude

                if let p = touchPoint, touchInfluence > 0.001 {
                    let radius = min(size.width, size.height) * 0.22
                    let ddx = x - p.x
                    let ddy = y0 - p.y
                    let dist2 = ddx*ddx + ddy*ddy

                    let falloff = exp(-dist2 / max(radius * radius, 1))
                    y += (p.y - y0) * bendStrength * falloff * touchInfluence
                }

                pts.append(CGPoint(x: x + xShift, y: y))
            }

            let smoothPath = makeSmoothPath(points: pts)

            ctx.stroke(smoothPath, with: .color(glow), lineWidth: 5.0 * weight)
            ctx.stroke(smoothPath, with: .color(core), lineWidth: 1.6 * weight)
        }
    }

    private func makeSmoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }

        path.move(to: points[0])

        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            let mid = CGPoint(x: (prev.x + curr.x) * 0.5,
                              y: (prev.y + curr.y) * 0.5)
            path.addQuadCurve(to: mid, control: prev)
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }

    // MARK: - Interaction

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchPoint = value.location
                touchInfluence = min(1, touchInfluence + 0.12)
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.35)) {
                    touchInfluence = 0
                }
            }
    }

    private func parallaxOffset(in size: CGSize) -> CGSize {
        guard parallax, let p = touchPoint, touchInfluence > 0.001 else { return .zero }

        let nx = (p.x / max(size.width, 1)) - 0.5
        let ny = (p.y / max(size.height, 1)) - 0.5

        return CGSize(
            width: nx * parallaxStrength,
            height: -ny * parallaxStrength
        )
    }
}

#Preview {
    FloatingLinesBackground(
        enabledWaves: [.top, .middle, .bottom], interactive: false, parallax: false, colors: [.white.opacity(0.7), .white.opacity(0.4)], baseBackground: Color(.systemBackground)
    )
}
