import SwiftUI
import AppKit

/// macOS 26 Liquid Glass with a system-material fallback on macOS 14 and 15.
/// `TOKENTRAY_NO_GLASS=1` forces the fallback (used for offscreen layout snapshots).
let useGlass: Bool = {
    guard ProcessInfo.processInfo.environment["TOKENTRAY_NO_GLASS"] == nil else { return false }
    if #available(macOS 26.0, *) { return true } else { return false }
}()

extension View {
    @ViewBuilder
    func glassCard(_ tint: Color? = nil, radius: CGFloat = 14, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(macOS 26.0, *), useGlass {
            let base: Glass = tint.map { Glass.regular.tint($0.opacity(0.22)) } ?? .regular
            self.glassEffect(interactive ? base.interactive() : base, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.fill((tint ?? .clear).opacity(0.10)))
                .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassButton(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *), useGlass {
            if prominent { self.buttonStyle(.glassProminent).tint(tint) } else { self.buttonStyle(.glass).tint(tint) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent).tint(tint) } else { self.buttonStyle(.bordered).tint(tint) }
        }
    }

    @ViewBuilder
    func glassMorphID(_ id: String, in ns: Namespace.ID) -> some View {
        if #available(macOS 26.0, *) { self.glassEffectID(id, in: ns) } else { self }
    }
}

/// Groups glass shapes so they blend and morph into each other on macOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content
    var body: some View {
        if #available(macOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content } } else { content }
    }
}

/// System window material for the Add key window.
struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

enum Motion {
    /// Confident arrival: fast start, soft landing. No bounce.
    static let arrive = Animation.spring(response: 0.42, dampingFraction: 0.88)
    static let quick = Animation.easeOut(duration: 0.16)
    static let roll = Animation.snappy(duration: 0.35)

    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

extension AnyTransition {
    static var rise: AnyTransition {
        .asymmetric(insertion: .opacity.combined(with: .offset(y: 6)).combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity)
    }
}
