import SwiftUI
import AppKit

/// A small glass window, opened from the menu bar panel.
enum AddKeyWindow {
    private static var window: NSWindow?

    @MainActor static func show(store: Store) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Add API key"
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.isOpaque = false
            w.backgroundColor = .clear
            w.contentViewController = NSHostingController(rootView: AddKeyView { w.close() }.environmentObject(store))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AddKeyView: View {
    /// The add flow is one of these, never a mix of booleans.
    enum Phase: Equatable {
        case entry
        case scanning(tried: Set<Provider>)
        case done(KeyRecord, byTesting: Bool)
        case consent(String)     // ask before the key goes to providers it may not belong to
        case failed(String)
    }

    @EnvironmentObject var store: Store
    let close: () -> Void
    @State private var secret = ""
    @State private var name = ""
    @State private var phase: Phase = .entry
    @Namespace private var badges
    @State private var pointer: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                AppMark(size: 18)
                Text(title).font(DS.Text.title).contentTransition(.opacity)
            }
            .padding(.top, 6)

            switch phase {
            case .entry, .failed: entry
            case .scanning(let tried): scanner(tried)
            case .consent(let reason): consent(reason)
            case .done(let rec, let byTesting): result(rec, byTesting: byTesting)
            }
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 18)
        .frame(width: 420)
        .background(WindowMaterial().ignoresSafeArea())
        .animation(reduce ? nil : Motion.arrive, value: phase)
    }

    private var title: String {
        switch phase {
        case .entry, .failed: "Add an API key"
        case .consent: "Which provider is this?"
        case .scanning: "Finding the provider…"
        case .done: "Key added"
        }
    }

    // MARK: Entry

    private var entry: some View {
        VStack(alignment: .leading, spacing: 10) {
            SecureField("Paste any AI API key", text: $secret)
                .textFieldStyle(.plain)
                .font(DS.Text.mono)
                .padding(10)
                .glassCard(radius: 10)
                .onSubmit { start() }
            Text(hint).font(DS.Text.meta).foregroundStyle(DS.Palette.secondary).contentTransition(.opacity)
            TextField("Name (optional)", text: $name)
                .textFieldStyle(.plain).padding(10).glassCard(radius: 10)
            if case .failed(let why) = phase {
                Label(why, systemImage: "exclamationmark.triangle.fill")
                    .font(DS.Text.body).foregroundStyle(DS.Palette.critical)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.rise)
            }
            Text("The key is checked with its own provider, then kept only in your Mac's Keychain.")
                .font(DS.Text.meta).foregroundStyle(DS.Palette.tertiary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel", action: close).keyboardShortcut(.cancelAction).glassButton()
                Button("Check & add") { start() }
                    .keyboardShortcut(.defaultAction)
                    .glassButton(prominent: true, tint: DS.Palette.tint)
                    .buttonBorderShape(.capsule)
                    .disabled(secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .transition(.rise)
    }

    private var hint: String {
        let s = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "Works with OpenRouter, Gemini, Groq, OpenAI, Anthropic, DeepSeek, xAI and 8 more." }
        if let p = Provider.hints(for: s).first { return "Looks like \(p.display). It will be checked only with \(p.display)." }
        return "Unfamiliar format. You'll choose the provider next."
    }

    // MARK: Scanning (signature moment)

    private func scanner(_ tried: Set<Provider>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 10), count: 8), spacing: 10) {
                ForEach(Array(Provider.allCases.enumerated()), id: \.element) { i, p in
                    let lit = tried.contains(p)
                    ProviderTile(provider: p, size: 34)
                        .matchedGeometryEffect(id: p, in: badges)
                        .saturation(lit ? 1 : 0)
                        .opacity(lit ? 1 : 0.28)
                        .scaleEffect((lit ? 1 : 0.86) * dockScale(i))
                        .zIndex(dockScale(i))
                        .animation(reduce ? nil : Motion.arrive, value: lit)
                        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.7), value: pointer)
                        .help(p.display)
                }
            }
            .onContinuousHover { phase in
                guard !reduce else { return }
                if case .active(let p) = phase { pointer = p } else { pointer = nil }
            }
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asked \(tried.count) of \(Provider.allCases.count) providers")
                    .font(DS.Text.body).foregroundStyle(DS.Palette.secondary).monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .transition(.opacity)
    }

    /// Dock-style magnification: badges near the cursor grow, falling off with distance.
    private func dockScale(_ i: Int) -> CGFloat {
        guard let pointer else { return 1 }
        let center = CGPoint(x: CGFloat(i % 8) * 50 + 20, y: CGFloat(i / 8) * 44 + 17)
        let d = hypot(pointer.x - center.x, pointer.y - center.y)
        return 1 + 0.32 * max(0, 1 - d / 80)
    }

    // MARK: Result

    private func result(_ rec: KeyRecord, byTesting: Bool) -> some View {
        let status = store.statuses[rec.id]
        let entry = Advice.Entry(key: rec, status: status, runwayDays: nil)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ProviderTile(provider: rec.provider, size: 44)
                    .matchedGeometryEffect(id: rec.provider, in: badges)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(rec.provider.display) key").font(DS.Text.title)
                    HStack(spacing: 5) {
                        StatusLabel(health: entry.health)
                        Text(byTesting ? "Identified by testing it" : "Recognised and confirmed")
                            .font(DS.Text.meta).foregroundStyle(DS.Palette.secondary)
                    }
                    Text(PanelText.summary(entry)).font(DS.Text.figure).monospacedDigit()
                }
            }
            if let status {
                DetailsList(status: status, key: rec)
                    .padding(12).glassCard(radius: 12)
            }
            HStack {
                TextField("Name", text: $name).textFieldStyle(.plain).padding(8).glassCard(radius: 8)
                Button("Done") {
                    store.rename(rec.id, to: name)
                    reset(); close()
                }
                .keyboardShortcut(.defaultAction)
                .glassButton(prominent: true, tint: DS.Palette.tint)
                    .buttonBorderShape(.capsule)
            }
        }
        .transition(.rise)
        .onAppear { if name.isEmpty { name = rec.nickname } }
    }

    // MARK: Flow

    private func start(_ scope: Adapters.Scope = .hints) {
        if case .scanning = phase { return }
        if case .done = phase { return }
        let key = secret
        phase = .scanning(tried: [])
        Task {
            let result = await store.add(secret: key, nickname: name, scope: scope) { p in
                await MainActor.run {
                    if case .scanning(var tried) = phase { tried.insert(p); phase = .scanning(tried: tried) }
                }
            }
            switch result {
            case .added(let rec, let byTesting):
                Motion.tap()
                secret = ""
                phase = .done(rec, byTesting: byTesting)
            case .duplicate(let n): phase = .failed("Already added as \"\(n)\".")
            case .rejectedBy(let p): phase = .consent("This looks like a \(p.display) key, but \(p.display) rejected it. It may be deleted or copied incompletely, or it may belong to another provider.")
            case .needsConsent: phase = .consent("TokenTray doesn't recognise this key's format.")
            case .offline: phase = .failed("No internet connection. Connect and try again.")
            case .unknown:
                if case .all = scope {
                    phase = .failed("No provider accepted this key. It may be mistyped, revoked, or from a provider TokenTray doesn't know yet.")
                } else {
                    phase = .consent("The provider it was checked with didn't accept it.")
                }
            case .failed(let why): phase = .failed(why)
            }
        }
    }

    private func reset() { secret = ""; name = ""; phase = .entry }

    // MARK: Consent

    private func consent(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.m) {
            Text(reason).font(DS.Text.body).foregroundStyle(DS.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Menu {
                ForEach(Provider.allCases, id: \.self) { p in
                    Button(p.display) { start(.only(p)) }
                }
            } label: {
                Label("Choose the provider", systemImage: "list.bullet").font(DS.Text.body.weight(.medium))
            }
            .menuStyle(.button)
            .glassButton(prominent: true, tint: DS.Palette.tint)
            .buttonBorderShape(.capsule)
            .fixedSize()
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Button { start(.all) } label: {
                    Label("Test with all \(Provider.allCases.count) providers", systemImage: "square.grid.3x3")
                        .font(DS.Text.body.weight(.medium))
                }
                .glassButton()
                .buttonBorderShape(.capsule)
                Text("This sends the key to each provider's official API to see which one accepts it.")
                    .font(DS.Text.meta).foregroundStyle(DS.Palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Back") { phase = .entry }.glassButton().buttonBorderShape(.capsule)
            }
        }
        .transition(.rise)
    }
}
