// G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI
import AppKit

/// "Quiet instrument": the one source of truth for colour, type, space and shape.
/// Visual reference: tokentray-design/stylesheet.html. Every view reads from here.
enum DS {
    enum Palette {
        static let label = Color(nsColor: .labelColor)
        static let secondary = Color(nsColor: .secondaryLabelColor)
        static let tertiary = Color(nsColor: .tertiaryLabelColor)
        static let separator = Color(nsColor: .separatorColor)
        static let fill = Color.primary.opacity(0.045)
        static let tint = Color(nsColor: .systemIndigo)
        static let positive = Color(nsColor: .systemGreen)
        static let caution = Color(nsColor: .systemOrange)
        static let critical = Color(nsColor: .systemRed)

        static func status(_ h: Health) -> Color {
            switch h { case .ok: positive; case .low: caution; case .blocked, .error: critical }
        }
    }

    enum Space {
        static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 20
    }

    enum Radius {
        static let tile: CGFloat = 7, row: CGFloat = 10, card: CGFloat = 16, panel: CGFloat = 20
    }

    enum Size {
        static let panelWidth: CGFloat = 360
        static let tile: CGFloat = 26
        static let heroTile: CGFloat = 32
    }

    /// Hierarchy from size and tone. Regular, medium and light only; never bold.
    enum Text {
        static let heroFigure = Font.system(size: 30, weight: .light, design: .rounded)
        static let title = Font.system(size: 15, weight: .medium)
        static let name = Font.system(size: 13, weight: .medium)
        static let figure = Font.system(size: 13, weight: .medium, design: .rounded)
        static let body = Font.system(size: 12)
        static let meta = Font.system(size: 11)
        static let overline = Font.system(size: 11, weight: .medium)
        static let mono = Font.system(size: 12, design: .monospaced)
    }
}

// MARK: - Atoms

/// Small uppercase section label.
struct Overline: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).font(DS.Text.overline).tracking(0.7).foregroundStyle(DS.Palette.tertiary)
    }
}

/// 6 pt dot plus secondary text.
struct StatusLabel: View {
    let health: Health
    var text: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(DS.Palette.status(health)).frame(width: 6, height: 6)
            if let text { Text(text).font(DS.Text.meta).foregroundStyle(DS.Palette.secondary) }
        }
    }
    static func word(_ h: Health) -> String {
        switch h { case .ok: "Healthy"; case .low: "Running low"; case .blocked: "Paused"; case .error: "Needs fixing" }
    }
}

/// Monogram on a 14% wash of the provider colour.
struct ProviderTile: View {
    let provider: Provider
    var size: CGFloat = DS.Size.tile
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = provider.color
        Text(provider.initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(scheme == .dark ? Color(nsColor: NSColor(c).blended(withFraction: 0.45, of: .white) ?? NSColor(c)) : c)
            .frame(width: size, height: size)
            .background(c.opacity(scheme == .dark ? 0.22 : 0.13),
                        in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

/// A thin 3 pt bar on a quiet track. Fills from zero when it appears.
struct MeterBar: View {
    let fraction: Double
    var color: Color = DS.Palette.positive
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(DS.Palette.fill)
                Capsule().fill(color)
                    .frame(width: max(3, g.size.width * (shown ? min(max(fraction, 0), 1) : 0)))
            }
        }
        .frame(height: 3)
        .onAppear { withAnimation(reduce ? nil : Motion.arrive.delay(0.08)) { shown = true } }
    }

    static func color(for fraction: Double) -> Color {
        fraction < 0.15 ? DS.Palette.critical : fraction < 0.4 ? DS.Palette.caution : DS.Palette.positive
    }
}

// MARK: - Brand mark: G.ai Token Tray by GauthamWho

/// The "G": a ring opened at the top right (the allowance), a crossbar like a gauge needle,
/// and a dot at the tip (where you are). Drawn on a 24-point grid.
struct GLetterShape: Shape {
    var dot = true
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        let o = CGPoint(x: r.midX - 12 * s, y: r.midY - 12 * s)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
        var g = Path()
        g.addArc(center: p(12, 12), radius: 7.2 * s, startAngle: .degrees(-45), endAngle: .degrees(0), clockwise: true)
        g.addLine(to: p(12.6, 12))
        var out = g.strokedPath(StrokeStyle(lineWidth: 2.6 * s, lineCap: .round, lineJoin: .round))
        if dot { out = out.union(Path(ellipseIn: CGRect(x: o.x + 15.0 * s, y: o.y + 4.8 * s, width: 4.2 * s, height: 4.2 * s))) }
        return out
    }
}

enum Brand {
    static let blue = Color(red: 0.12, green: 0.42, blue: 1.0)      // #1F6BFF
    static let deep = Color(red: 0.04, green: 0.24, blue: 0.80)     // #0A3DCC
    static let sky = Color(red: 0.56, green: 0.80, blue: 1.0)       // #8FCCFF
    static let name = "G.ai Token Tray"
    static let maker = "GauthamWho"
}

/// Blue squircle with the white G. Used as the app icon and the panel mark.
struct AppMark: View {
    var size: CGFloat = 18
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [Brand.blue, Brand.deep], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: max(0.5, size * 0.012))
            GLetterShape(dot: false).fill(.white).padding(size * 0.12)
            Circle().fill(Brand.sky)
                .frame(width: size * 0.133, height: size * 0.133)
                .offset(x: size * 0.1615, y: -size * 0.1615)
        }
        .frame(width: size, height: size)
    }
}

extension AppMark {
    /// Menu bar: just the G. A template image (adapts to the bar) unless a status colour is given.
    @MainActor static func menuBarImage(color: NSColor?) -> NSImage {
        let renderer = ImageRenderer(content: GLetterShape().fill(color.map { Color(nsColor: $0) } ?? .black).frame(width: 18, height: 18))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let img = renderer.nsImage ?? NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: nil)!
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = (color == nil)
        img.accessibilityDescription = Brand.name
        return img
    }
}

// MARK: - Still images

/// True only when rendering README stills offscreen, where AppKit-backed controls can't draw.
private struct StillRenderKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var stillRender: Bool {
        get { self[StillRenderKey.self] }
        set { self[StillRenderKey.self] = newValue }
    }
}

/// A text field that draws as plain text in still renders.
struct FieldOrStill: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var font: Font = DS.Text.body
    var onSubmit: () -> Void = {}
    @Environment(\.stillRender) private var still

    var body: some View {
        Group {
            if still {
                Text(text.isEmpty ? placeholder : (secure ? String(repeating: "•", count: min(text.count, 30)) : text))
                    .foregroundStyle(text.isEmpty ? DS.Palette.tertiary : DS.Palette.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if secure {
                SecureField(placeholder, text: $text).textFieldStyle(.plain).onSubmit(onSubmit)
            } else {
                TextField(placeholder, text: $text).textFieldStyle(.plain).onSubmit(onSubmit)
            }
        }
        .font(font)
    }
}
