// G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI

/// Pointer-driven physics shared by every interactive surface.
/// All effects switch off under Reduce Motion.

/// A soft light that follows the cursor across a surface and fades when it leaves.
struct PointerGlow: ViewModifier {
    var color: Color = .white
    var radius: CGFloat = 140
    var strength: Double = 0.22
    var cornerRadius: CGFloat = 14
    @State private var point: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .overlay {
                if let point, !reduce {
                    RadialGradient(colors: [color.opacity(scheme == .dark ? strength : strength * 0.9), .clear],
                                   center: .init(x: 0, y: 0), startRadius: 0, endRadius: radius)
                        .offset(x: point.x, y: point.y)
                        .frame(width: 0, height: 0, alignment: .topLeading)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .blendMode(scheme == .dark ? .plusLighter : .softLight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let p):
                    if point == nil { withAnimation(.easeOut(duration: 0.2)) { point = p } }
                    else { point = p }
                case .ended:
                    withAnimation(.easeOut(duration: 0.35)) { point = nil }
                }
            }
    }
}

/// Leans the surface toward the cursor in 3D, and lets it be flung: it follows the drag with
/// rubber-band resistance, then springs home carrying the release velocity.
struct TiltAndFling: ViewModifier {
    var maxTilt: Double = 5
    @State private var tilt: CGSize = .zero
    @State private var drag: CGSize = .zero
    @State private var pressed = false
    @State private var size: CGSize = CGSize(width: 1, height: 1)
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content
                .background(SizeReader(size: $size))
                .rotation3DEffect(.degrees(Double(tilt.height) * maxTilt), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
                .rotation3DEffect(.degrees(Double(-tilt.width) * maxTilt), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                .scaleEffect(pressed ? 0.985 : 1)
                .offset(drag)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    guard !reduce else { return }
                    switch phase {
                    case .active(let p):
                        let t = CGSize(width: (p.x / max(size.width, 1) - 0.5) * 2,
                                       height: (p.y / max(size.height, 1) - 0.5) * 2)
                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.8)) { tilt = t }
                    case .ended:
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { tilt = .zero }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            guard !reduce else { return }
                            if !pressed { withAnimation(Motion.quick) { pressed = true } }
                            drag = CGSize(width: rubber(v.translation.width, limit: 40),
                                          height: rubber(v.translation.height, limit: 28))
                        }
                        .onEnded { v in
                            let speed = hypot(v.velocity.width, v.velocity.height)
                            let bounce = min(0.2, 0.1 + speed / 12000)
                            withAnimation(.spring(duration: 0.55, bounce: bounce)) { drag = .zero; pressed = false }
                            if speed > 800 { Motion.tap() }
                        }
                )
    }

    /// Resistance grows the further you pull, like iOS overscroll.
    private func rubber(_ x: CGFloat, limit: CGFloat) -> CGFloat {
        let s: CGFloat = x < 0 ? -1 : 1
        return s * limit * (1 - 1 / (abs(x) / limit * 0.55 + 1))
    }
}

/// Pulls a small element a few points toward the cursor and grows it slightly.
struct Magnetic: ViewModifier {
    var pull: CGFloat = 3
    var grow: CGFloat = 1.08
    @State private var offset: CGSize = .zero
    @State private var hovering = false
    @State private var size: CGSize = CGSize(width: 1, height: 1)
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content
                .background(SizeReader(size: $size))
                .scaleEffect(hovering ? grow : 1)
                .offset(offset)
                .onContinuousHover(coordinateSpace: .local) { phase in
                    guard !reduce else { return }
                    switch phase {
                    case .active(let p):
                        let o = CGSize(width: (p.x / max(size.width, 1) - 0.5) * 2 * pull,
                                       height: (p.y / max(size.height, 1) - 0.5) * 2 * pull)
                        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.7)) { offset = o; hovering = true }
                    case .ended:
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { offset = .zero; hovering = false }
                    }
                }
    }
}

/// Reports a view's size without affecting its layout.
struct SizeReader: View {
    @Binding var size: CGSize
    var body: some View {
        GeometryReader { g in
            Color.clear
                .onAppear { size = g.size }
                .onChange(of: g.size) { _, new in size = new }
        }
    }
}

/// Squishes slightly while pressed and springs back on release.
struct PressSquish: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

extension View {
    func pointerGlow(_ color: Color = .white, radius: CGFloat = 140, strength: Double = 0.22, corner: CGFloat = 14) -> some View {
        modifier(PointerGlow(color: color, radius: radius, strength: strength, cornerRadius: corner))
    }
    func tiltAndFling(_ maxTilt: Double = 5) -> some View { modifier(TiltAndFling(maxTilt: maxTilt)) }
    func magnetic(pull: CGFloat = 3, grow: CGFloat = 1.08) -> some View { modifier(Magnetic(pull: pull, grow: grow)) }
}
