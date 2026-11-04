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

// MARK: - App mark

/// The ring gauge: an open arc (the allowance), a dot where you are, and a needle.
struct AppMarkShape: Shape {
    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }
        var path = Path()
        path.addArc(center: p(12, 12), radius: 8 * s, startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
        return path.strokedPath(StrokeStyle(lineWidth: 2.2 * s, lineCap: .round))
            .union(Path(ellipseIn: CGRect(origin: p(16.55, 15.4), size: CGSize(width: 4.2 * s, height: 4.2 * s))))
            .union({ var n = Path(); n.move(to: p(12, 12)); n.addLine(to: p(15.6, 8.4))
                     return n.strokedPath(StrokeStyle(lineWidth: 2 * s, lineCap: .round)) }())
            .union(Path(ellipseIn: CGRect(origin: p(10.4, 10.4), size: CGSize(width: 3.2 * s, height: 3.2 * s))))
    }
}

struct AppMark: View {
    var size: CGFloat = 16
    var color: Color = DS.Palette.tint
    var body: some View { AppMarkShape().fill(color).frame(width: size, height: size) }
}

extension AppMark {
    /// Menu bar image: a template (adapts to the bar) unless a colour is given.
    @MainActor static func menuBarImage(color: NSColor?) -> NSImage {
        let renderer = ImageRenderer(content: AppMarkShape().fill(color.map { Color(nsColor: $0) } ?? .black).frame(width: 18, height: 18))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let img = renderer.nsImage ?? NSImage(systemSymbolName: "gauge.with.dots.needle.33percent", accessibilityDescription: nil)!
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = (color == nil)
        img.accessibilityDescription = "TokenTray"
        return img
    }
}
