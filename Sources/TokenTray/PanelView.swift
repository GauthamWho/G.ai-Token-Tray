// G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI

/// The menu bar popover, built only from DS tokens. Layout reference: stylesheet.html, "Panel, assembled".
struct PanelView: View {
    @EnvironmentObject var store: Store
    @Environment(\.stillRender) private var still
    @Namespace private var glass
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let advice = store.advice
        VStack(alignment: .leading, spacing: 0) {
            header
            if store.keys.isEmpty {
                EmptyCard()
            } else {
                GlassGroup(spacing: DS.Space.m) {
                    Group {
                        if let best = advice.best {
                            HeroCard(entry: best, why: advice.why)
                                .id(best.id)
                                .transition(.rise)
                        } else {
                            NoneCard(why: advice.why)
                        }
                    }
                    .glassMorphID("hero", in: glass)
                }
                .animation(reduce ? nil : Motion.arrive, value: advice.best?.id)
                list(advice)
            }
            footer
        }
        .padding(DS.Space.m)
        .frame(width: DS.Size.panelWidth)
        .onAppear { withAnimation(reduce ? nil : Motion.arrive) { shown = true } }
        .onDisappear { shown = false }
        .environment(\.panelShown, shown)
    }

    private var header: some View {
        HStack(spacing: DS.Space.s) {
            AppMark(size: 16)
            Text(Brand.name).font(DS.Text.name)
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text(store.refreshing ? "Checking…" : store.lastRefresh.map { "Updated \(Fmt.ago($0, now: ctx.date))" } ?? "")
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.meta).monospacedDigit()
                    .contentTransition(.opacity)
            }
            Button { Motion.tap(); Task { await store.refresh() } } label: {
                RefreshIcon(spinning: store.refreshing).font(.system(size: 11, weight: .medium))
            }
            .glassButton()
            .controlSize(.small)
            .buttonBorderShape(.circle)
            .help("Check all keys now (⌘R)")
            .keyboardShortcut("r")
            .disabled(store.refreshing)
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.bottom, DS.Space.m)
    }

    private func list(_ advice: Advice) -> some View {
        let back = advice.comingBack.enumerated().map { i, c in
            (c.entry, KeyRow.Trailing.countdown(c.at), i, Optional(c.label.prefix(1).uppercased() + c.label.dropFirst()))
        }
        let rest = advice.others.enumerated().map { i, e in (e, KeyRow.Trailing.value, back.count + i, String?.none) }
        return VStack(alignment: .leading, spacing: 0) {
            ForEach([("Coming back", back), ("Other keys", rest)].filter { !$0.1.isEmpty }, id: \.0) { section in
                Overline(section.0)
                    .padding(.horizontal, DS.Space.s)
                    .padding(.top, DS.Space.l).padding(.bottom, DS.Space.xs)
                ForEach(section.1, id: \.0.id) { item in
                    KeyRow(entry: item.0, trailing: item.1, order: item.2, metaOverride: item.3)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button { AddKeyWindow.show(store: store) } label: {
                Label("Add key", systemImage: "plus").font(DS.Text.body.weight(.medium))
            }
            .glassButton()
            .buttonBorderShape(.capsule)
            .keyboardShortcut("n")
            .help("Add key (⌘N)")
            Spacer()
            Text("\(store.keys.count) \(store.keys.count == 1 ? "key" : "keys")")
                .font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
            Group {
                if still {
                    Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(DS.Palette.meta)
                } else {
                    Menu {
                        Button("Check all keys now") { Task { await store.refresh() } }
                        Divider()
                        Button("Quit \(Brand.name)") { NSApp.terminate(nil) }.keyboardShortcut("q")
                    } label: {
                        Image(systemName: "gearshape").font(.system(size: 13)).foregroundStyle(DS.Palette.meta)
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                }
            }
        }
        .padding(.horizontal, DS.Space.s)
        .padding(.top, DS.Space.m)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.Palette.separator).frame(height: 0.5)
        }
        .padding(.top, DS.Space.m)
    }
}

// MARK: - Copy

/// What the panel says about a key, in one place.
enum PanelText {
    /// The big number and its unit for the hero card.
    static func figure(_ e: Advice.Entry) -> (value: String, unit: String, fraction: Double?) {
        guard let s = e.status else { return ("—", "not checked yet", nil) }
        if let left = s.remaining {
            let unit = s.total.map { "left of \(Fmt.money($0, s.currency))" } ?? "left"
            return (exact(left, s.currency), unit, s.total.flatMap { $0 > 0 ? left / $0 : nil })
        }
        if let w = s.limits.min(by: { $0.fraction < $1.fraction }) {
            return ("\(Fmt.count(w.remaining))", "of \(Fmt.count(w.limit)) \(w.name)", w.fraction)
        }
        return ("Ready", "usage not shared", nil)
    }

    /// Cents always shown in the hero figure.
    static func exact(_ v: Double, _ code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = code
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    /// The short value at the end of a row.
    static func value(_ e: Advice.Entry) -> String {
        guard let s = e.status, s.health != .error else { return "" }
        if let left = s.remaining { return Fmt.money(left, s.currency) }
        if let w = s.limits.min(by: { $0.fraction < $1.fraction }) { return "\(Fmt.count(w.remaining))/\(Fmt.count(w.limit))" }
        return "Ready"
    }

    /// The grey line under a key's name.
    static func meta(_ e: Advice.Entry) -> String {
        guard let s = e.status else { return "Not checked yet" }
        if s.health == .error || s.stale || s.health == .blocked { return s.note }
        if s.remaining != nil {
            if let r = Fmt.runway(e.runwayDays) { return r.prefix(1).uppercased() + r.dropFirst() }
            if let today = s.usedToday, today > 0 { return "\(Fmt.money(today, s.currency)) used today" }
            return e.key.provider.display
        }
        if let w = s.limits.min(by: { $0.fraction < $1.fraction }) { return w.name.prefix(1).uppercased() + w.name.dropFirst() }
        return "Works · \(e.key.provider.display.split(separator: " ").first ?? "") doesn't share usage"
    }

    /// One line for the add-key result.
    static func summary(_ e: Advice.Entry) -> String {
        let f = figure(e)
        return f.value == "Ready" ? meta(e) : "\(f.value) \(f.unit)"
    }
}

private struct PanelShownKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    var panelShown: Bool {
        get { self[PanelShownKey.self] }
        set { self[PanelShownKey.self] = newValue }
    }
}

struct RefreshIcon: View {
    let spinning: Bool
    var body: some View {
        if #available(macOS 15.0, *) {
            Image(systemName: "arrow.clockwise").symbolEffect(.rotate, isActive: spinning)
        } else {
            Image(systemName: "arrow.clockwise").opacity(spinning ? 0.5 : 1)
        }
    }
}

// MARK: - Hero

struct HeroCard: View {
    @EnvironmentObject var store: Store
    let entry: Advice.Entry
    let why: String
    @State private var copied = false
    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let fig = PanelText.figure(entry)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Overline("Use this now")
                Spacer()
                StatusLabel(health: entry.health, text: StatusLabel.word(entry.health))
            }
            HStack(spacing: DS.Space.s + 2) {
                ProviderTile(provider: entry.key.provider, size: DS.Size.heroTile).magnetic(pull: 3, grow: 1.05)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.key.nickname).font(DS.Text.title).lineLimit(1)
                    Text("\(entry.key.provider.display) · \(entry.key.masked)")
                        .font(DS.Text.meta).foregroundStyle(DS.Palette.meta).lineLimit(1)
                }
                Spacer(minLength: DS.Space.s)
                Button {
                    Task {
                        if await store.copyKey(entry.id) {
                            Motion.tap()
                            withAnimation(Motion.quick) { copied = true }
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(Motion.quick) { copied = false }
                        }
                    }
                } label: {
                    Label(copied ? "Copied" : "Use", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(DS.Text.body.weight(.medium))
                        .contentTransition(.symbolEffect(.replace))
                }
                .glassButton(prominent: true, tint: DS.Palette.tintFill)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
                .help("Copy this key (↩, asks for Touch ID). The clipboard clears after 60 seconds.")
            }
            .padding(.top, DS.Space.s + 2)

            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                Text(fig.value).font(DS.Text.heroFigure).tracking(-0.5).monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(Motion.roll, value: fig.value)
                Text(fig.unit).font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
                Spacer(minLength: 0)
                if let r = Fmt.runway(entry.runwayDays) {
                    Text(r).font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
                }
            }
            .padding(.top, DS.Space.m + 2)
            if let f = fig.fraction {
                MeterBar(fraction: f, color: MeterBar.color(for: f)).padding(.top, DS.Space.s)
            }
            Text(why).font(DS.Text.body).foregroundStyle(DS.Palette.meta)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, DS.Space.m)
            if open, let s = entry.status {
                DetailsList(status: s, key: entry.key).padding(.top, DS.Space.m).transition(.rise)
            }
        }
        .padding(DS.Space.l)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(reduce ? nil : Motion.arrive) { open.toggle() } }
        .pointerGlow(.white, radius: 170, strength: 0.2, corner: DS.Radius.card)
        .glassCard(radius: DS.Radius.card, interactive: true)
    }
}

struct NoneCard: View {
    let why: String
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack { Overline("Use this now"); Spacer(); StatusLabel(health: .error, text: "Nothing usable") }
            Text("No key has room right now").font(DS.Text.title)
            Text(why).font(DS.Text.body).foregroundStyle(DS.Palette.meta)
        }
        .padding(DS.Space.m + 2).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(DS.Palette.critical.opacity(0.4), radius: DS.Radius.card)
    }
}

struct EmptyCard: View {
    @EnvironmentObject var store: Store
    var body: some View {
        VStack(spacing: DS.Space.s) {
            AppMark(size: 30)
            Text("Add your first key").font(DS.Text.title).padding(.top, DS.Space.xs)
            Text("Paste any AI key. TokenTray finds the provider and reads its credit and limits.")
                .font(DS.Text.body).foregroundStyle(DS.Palette.meta).multilineTextAlignment(.center)
            Button("Add key") { AddKeyWindow.show(store: store) }
                .glassButton(prominent: true, tint: DS.Palette.tintFill)
                .buttonBorderShape(.capsule)
                .padding(.top, DS.Space.s)
        }
        .padding(DS.Space.xl).frame(maxWidth: .infinity)
        .glassCard(radius: DS.Radius.card)
    }
}

// MARK: - Rows

struct KeyRow: View {
    enum Trailing { case countdown(Date), value }
    @EnvironmentObject var store: Store
    let entry: Advice.Entry
    let trailing: Trailing
    var order: Int = 0
    var metaOverride: String? = nil
    @State private var open = false
    @State private var hover = false
    @Environment(\.panelShown) private var shown
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Space.s + 2) {
                ProviderTile(provider: entry.key.provider).magnetic()
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.key.nickname).font(DS.Text.name).lineLimit(1)
                    Text(metaOverride ?? PanelText.meta(entry)).font(DS.Text.meta)
                        .foregroundStyle(metaOverride != nil || entry.health <= .low ? DS.Palette.meta : DS.Palette.criticalText)
                        .lineLimit(1)
                }
                Spacer(minLength: DS.Space.s)
                trailingView
            }
            if open, let s = entry.status {
                DetailsList(status: s, key: entry.key)
                    .padding(.top, DS.Space.m).padding(.leading, DS.Size.tile + DS.Space.s + 2)
                    .transition(.rise)
            }
        }
        .padding(DS.Space.s)
        .background {
            if hover || open {
                RoundedRectangle(cornerRadius: DS.Radius.row, style: .continuous).fill(DS.Palette.fill)
            }
        }
        .pointerGlow(.white, radius: 120, strength: 0.16, corner: DS.Radius.row)
        .offset(y: hover && !reduce ? -1 : 0)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(Motion.quick) { hover = h } }
        .onTapGesture { withAnimation(reduce ? nil : Motion.arrive) { open.toggle() } }
        .opacity(shown ? 1 : 0)
        .offset(y: shown || reduce ? 0 : 6)
        .animation(reduce ? nil : Motion.arrive.delay(min(Double(order) * 0.035, 0.25)), value: shown)
        .help(entry.key.masked)
        .contextMenu {
            Button("Copy key (Touch ID)") { Task { _ = await store.copyKey(entry.id) } }
            Divider()
            Button("Remove \(entry.key.nickname)", role: .destructive) { withAnimation(reduce ? nil : Motion.arrive) { store.remove(entry.id) } }
        }
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .countdown(let at):
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Fmt.countdown(to: at, now: ctx.date)).font(DS.Text.figure)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(Motion.roll, value: Int(ctx.date.timeIntervalSince1970))
                    Text(Fmt.clock(at)).font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
                }
                .monospacedDigit()
            }
        case .value:
            let v = PanelText.value(entry)
            HStack(spacing: DS.Space.s - 2) {
                if entry.health != .ok { Circle().fill(DS.Palette.status(entry.health)).frame(width: 6, height: 6) }
                Text(v).font(DS.Text.figure).monospacedDigit()
                    .foregroundStyle(v == "Ready" || entry.status?.stale == true ? DS.Palette.meta : DS.Palette.label)
                    .contentTransition(.numericText())
                    .animation(Motion.roll, value: v)
            }
        }
    }
}

/// Everything the provider told us about a key.
struct DetailsList: View {
    @EnvironmentObject var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduce
    let status: KeyStatus
    let key: KeyRecord

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if let left = status.remaining, let total = status.total, total > 0 {
                meter("Credit", "\(Fmt.money(left, status.currency)) of \(Fmt.money(total, status.currency))", left / total, nil)
            }
            ForEach(Array(status.limits.enumerated()), id: \.offset) { _, w in
                meter(w.name.prefix(1).uppercased() + w.name.dropFirst(), "\(Fmt.count(w.remaining)) / \(Fmt.count(w.limit))", w.fraction, w.resetAt)
            }
            Grid(alignment: .leading, horizontalSpacing: DS.Space.m, verticalSpacing: DS.Space.xs) {
                row("Provider", key.provider.display)
                row("Key", key.masked, mono: true)
                ForEach(Array(status.details.enumerated()), id: \.offset) { _, pair in
                    if pair.count == 2 { row(pair[0], pair[1]) }
                }
                row("Checked", Fmt.clock(status.updatedAt))
            }
            if !status.note.isEmpty {
                Text(status.note).font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DS.Space.s) {
                Button("Copy key") { Task { _ = await store.copyKey(key.id) } }.glassButton()
                Button("Remove", role: .destructive) { withAnimation(reduce ? nil : Motion.arrive) { store.remove(key.id) } }
                    .glassButton(tint: DS.Palette.criticalText)
            }
            .controlSize(.small)
            .buttonBorderShape(.capsule)
        }
    }

    private func row(_ label: String, _ value: String, mono: Bool = false) -> some View {
        GridRow {
            Text(label).font(DS.Text.meta).foregroundStyle(DS.Palette.meta)
            Text(value).font(mono ? .system(size: 11, design: .monospaced) : DS.Text.meta)
                .foregroundStyle(DS.Palette.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func meter(_ name: String, _ value: String, _ fraction: Double, _ reset: Date?) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.xs) {
                Text(name).font(DS.Text.meta.weight(.medium))
                Spacer()
                Text(value).font(DS.Text.meta).monospacedDigit()
                if let reset { Text("· \(Fmt.clock(reset))").font(DS.Text.meta).foregroundStyle(DS.Palette.meta) }
            }
            MeterBar(fraction: fraction, color: MeterBar.color(for: fraction))
        }
    }
}
