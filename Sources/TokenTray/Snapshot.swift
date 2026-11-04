// G.AI TokenTray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import SwiftUI

/// `TokenTray --snapshot <dir>` renders the real panel with sample keys to PNGs (light + dark), then exits.
enum PanelSnapshot {
    /// `TokenTray --selftest` checks key recognition and reset parsing on made-up keys.
    static func selfTestIfRequested() {
        guard CommandLine.arguments.contains("--selftest") else { return }
        let x32 = String(repeating: "a1", count: 16)
        let cases: [(String, Provider?)] = [
            ("sk-or-v1-" + x32 + x32, .openRouter),
            ("  sk-or-v1-" + x32 + "\n", .openRouter),
            ("sk-" + x32, .deepSeek),
            ("AIzaSy" + String(repeating: "B", count: 33), .gemini),
            ("AQ.Ab8RN6" + String(repeating: "x", count: 40), .gemini),
            ("gsk_" + String(repeating: "C", count: 52), .groq),
            ("sk-ant-api03-" + x32, .anthropic),
            ("sk-proj-" + x32, .openAI),
            ("sk-" + x32 + "zz", .openAI),
            ("xai-" + x32, .xai),
            ("csk-" + x32, .cerebras),
            ("hf_" + x32, .huggingFace),
            ("hello", nil),
        ]
        var failed = 0
        for (key, want) in cases where Provider.hints(for: key).first != want {
            failed += 1; print("FAIL hint \(key.prefix(10))…: got \(String(describing: Provider.hints(for: key).first)), want \(String(describing: want))")
        }
        let headers: [AnyHashable: Any] = ["X-RateLimit-Limit-Requests": "1000", "x-ratelimit-remaining-requests": "812",
                                           "x-ratelimit-reset-requests": "2m59.56s", "x-ratelimit-limit-tokens-minute": "60000",
                                           "x-ratelimit-remaining-tokens-minute": "59000", "x-ratelimit-reset-tokens-minute": "12"]
        let ws = Adapters.limits(from: headers)
        if ws.count != 2 || ws.first(where: { $0.name == "requests today" })?.remaining != 812
            || ws.first(where: { $0.name == "tokens this minute" })?.limit != 60000 {
            failed += 1; print("FAIL limits: \(ws.map { "\($0.name) \($0.remaining)/\($0.limit)" })")
        }
        let times: [(String, TimeInterval?)] = [("2m59.56s", 179.56), ("7.66s", 7.66), ("1h2m3s", 3723), ("500ms", 0.5), ("abc", nil)]
        for (t, want) in times where Adapters.duration(t).map({ abs($0 - (want ?? -1)) < 0.001 }) != (want == nil ? nil : true) {
            failed += 1; print("FAIL duration \(t): got \(String(describing: Adapters.duration(t)))")
        }
        // An unfamiliar key must never leave the Mac without the user choosing where it goes.
        final class Probe: @unchecked Sendable { let lock = NSLock(); var sent: [Provider] = []; var result = "" }
        let probe = Probe()
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            let r = await Adapters.identify("hello-not-a-key", progress: { p in probe.lock.withLock { probe.sent.append(p) } })
            probe.lock.withLock { if case .needsConsent = r { probe.result = "needsConsent" } else { probe.result = "\(r)" } }
            done.signal()
        }
        done.wait()
        if probe.result != "needsConsent" || !probe.sent.isEmpty {
            failed += 1; print("FAIL consent: got \(probe.result), sent to \(probe.sent)")
        }
        for (v, want) in [(Double.infinity, "—"), (.nan, "—"), (1e300, "—"), (812.9, "812")] where Fmt.count(v) != want {
            failed += 1; print("FAIL count \(v): \(Fmt.count(v))")
        }
        let weird: [AnyHashable: Any] = ["x-ratelimit-limit-requests": "inf", "x-ratelimit-remaining-requests": "1e400",
                                         "x-ratelimit-limit-tokens": "100", "x-ratelimit-remaining-tokens": "50",
                                         "x-ratelimit-reset-tokens": "1e308"]
        let wl = Adapters.limits(from: weird)
        if wl.count != 1 || wl.first?.resetAt != nil { failed += 1; print("FAIL weird headers: \(wl)") }
        _ = Fmt.countdown(to: Date.distantFuture); _ = Fmt.ago(Date.distantPast)
        print(failed == 0 ? "selftest passed (\(cases.count + times.count + 7) checks)" : "selftest FAILED: \(failed)")
        exit(failed == 0 ? 0 : 1)
    }

    /// `TokenTray --preview <png>` shows the real panel with sample keys in a window,
    /// expands one row, captures the window with screencapture, then exits.
    @MainActor static func previewIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--preview"), i + 1 < args.count else { return }
        let out = args[i + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let store = Store(demo: sample())
            let w = NSWindow(contentRect: NSRect(x: 200, y: 200, width: DS.Size.panelWidth, height: 600),
                             styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isOpaque = false
            w.backgroundColor = .clear
            w.contentViewController = NSHostingController(rootView:
                PanelView().environmentObject(store).padding(.top, 6).background(WindowMaterial().ignoresSafeArea()))
            w.setContentSize(w.contentViewController!.view.fittingSize)
            w.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let v = w.contentView?.superview ?? w.contentView,
                   let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                exit(0)
            }
        }
    }

    /// `TOKENTRAY_NO_GLASS=1 TokenTray --readme-assets <dir>` renders the brand icon set,
    /// panel screenshots and add-key animation frames used in the README.
    @MainActor static func readmeAssetsIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--readme-assets"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        let fm = FileManager.default
        try? fm.createDirectory(at: dir.appendingPathComponent("AppIcon.iconset"), withIntermediateDirectories: true)
        try? fm.createDirectory(at: dir.appendingPathComponent("frames"), withIntermediateDirectories: true)

        func save<V: View>(_ v: V, _ path: String, scale: CGFloat = 2) {
            let r = ImageRenderer(content: v.environment(\.stillRender, true)); r.scale = scale
            guard let img = r.nsImage, let t = img.tiffRepresentation,
                  let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) else { return }
            try? png.write(to: dir.appendingPathComponent(path))
        }

        // App icon: macOS squircle with breathing room, at every iconset size.
        let icon = { (px: CGFloat) in
            AppMark(size: px * 0.8).shadow(color: .black.opacity(0.25), radius: px * 0.02, y: px * 0.015)
                .frame(width: px, height: px)
        }
        for (pt, scales) in [(16, [1, 2]), (32, [1, 2]), (128, [1, 2]), (256, [1, 2]), (512, [1, 2])] {
            for sc in scales {
                let name = sc == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
                save(icon(CGFloat(pt)), "AppIcon.iconset/\(name)", scale: CGFloat(sc))
            }
        }
        save(icon(512), "logo-1024.png")

        // Panel screenshots on a window-like card.
        let store = Store(demo: sample())
        for scheme in [ColorScheme.light, .dark] {
            let card = PanelView().environmentObject(store).environment(\.colorScheme, scheme)
                .background(scheme == .dark ? Color(white: 0.13) : Color(white: 0.985))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .padding(28)
                .environment(\.colorScheme, scheme)
            save(card, "panel-\(scheme == .dark ? "dark" : "light").png")
        }

        // Add-key animation frames: paste → scan lights up → result.
        let addStore = Store(demo: sample())
        let rec = addStore.keys[0]
        // An OpenRouter key is checked only with OpenRouter (no key goes elsewhere without consent).
        var phases: [AddKeyView.Phase] = [.entry, .entry, .entry, .scanning(tried: []), .scanning(tried: [.openRouter]), .scanning(tried: [.openRouter])]
        phases += Array(repeating: .done(rec, byTesting: false), count: 6)
        for (n, ph) in phases.enumerated() {
            let win = VStack(spacing: 0) {
                HStack(spacing: 7) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                        Circle().fill($0).frame(width: 11, height: 11)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 12)
                AddKeyView(close: {}, phase: ph, secret: n == 0 ? "" : "sk-or-v1-a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4")
                    .environmentObject(addStore)
            }
            .frame(width: 420, height: 430, alignment: .top)
            .background(Color(white: 0.975))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .padding(24)
            .environment(\.colorScheme, .light)
            save(win, String(format: "frames/add-%02d.png", n))
        }
        exit(0)
    }

    @MainActor static func runIfRequested() {
        readmeAssetsIfRequested()
        selfTestIfRequested()
        previewIfRequested()
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (scenario, store) in [("advisor", Store(demo: sample())), ("empty", Store(demo: ([], [:], [])))] {
            for scheme in [ColorScheme.light, .dark] {
                let view = PanelView().environmentObject(store).environment(\.colorScheme, scheme)
                let r = ImageRenderer(content: view)
                r.scale = 2
                guard let img = r.nsImage, let tiff = img.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
                try? png.write(to: dir.appendingPathComponent("\(scenario)-\(scheme == .light ? "light" : "dark").png"))
            }
        }
        for (name, c) in [("menubar", nil), ("menubar-red", NSColor.systemRed)] as [(String, NSColor?)] {
            let img = AppMark.menuBarImage(color: c)
            if let t = img.tiffRepresentation, let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
        exit(0)
    }

    private static func sample() -> ([KeyRecord], [UUID: KeyStatus], [Snapshot]) {
        func rec(_ n: String, _ p: Provider, _ m: String) -> KeyRecord {
            KeyRecord(id: UUID(), nickname: n, provider: p, fingerprint: n, masked: m, addedAt: Date())
        }
        let work = rec("Work OpenRouter", .openRouter, "sk-or-v1-…7a1c")
        let ds = rec("DeepSeek", .deepSeek, "sk-…91kd")
        let capped = rec("Script key", .openRouter, "sk-or-v1-…22be")
        let old = rec("Old OpenRouter", .openRouter, "sk-or-v1-…0f3e")
        var s: [UUID: KeyStatus] = [:]
        s[work.id] = KeyStatus(remaining: 18.40, total: 25, usedToday: 1.10, usedWeek: 21.7, health: .ok)
        s[ds.id] = KeyStatus(remaining: 1.20, total: 10, usedToday: 0.4, usedWeek: 2.8, health: .ok)
        s[capped.id] = KeyStatus(remaining: 0, total: 5, resetAt: Date().addingTimeInterval(6480),
                                 resetLabel: "daily spend cap resets", health: .blocked, note: "No credit left. Free models still work.")
        s[old.id] = KeyStatus(health: .error, note: FetchError.rejected.message)
        let gem = rec("Gemini", .gemini, "AIza…91kD")
        let groq = rec("Groq free", .groq, "gsk_…m2Pz")
        s[gem.id] = KeyStatus(health: .ok, note: "Key works. Google doesn't share usage or credit.",
                              details: [["Models available", "48"], ["Newest Gemini model", "gemini-3.8-flash"]])
        s[groq.id] = KeyStatus(health: .ok, limits: [LimitWindow(name: "requests today", remaining: 120, limit: 1000,
                                                                   resetAt: Date().addingTimeInterval(25900))])
        return ([work, ds, gem, groq, capped, old], s, [])
    }
}
