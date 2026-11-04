// G.ai Token Tray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import Foundation
import AppKit
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published private(set) var keys: [KeyRecord] = []
    @Published private(set) var statuses: [UUID: KeyStatus] = [:]
    @Published private(set) var history: [Snapshot] = []
    @Published private(set) var refreshing = false
    @Published private(set) var lastRefresh: Date?

    private var timer: Timer?
    private let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TokenTray", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    var advice: Advice { Advisor.advise(keys: keys, statuses: statuses, history: history) }

    /// Sample data for `--snapshot`, never saved or fetched.
    init(demo: (keys: [KeyRecord], statuses: [UUID: KeyStatus], history: [Snapshot])) {
        keys = demo.keys; statuses = demo.statuses; history = demo.history; lastRefresh = Date().addingTimeInterval(-12)
    }

    init() {
        keys = load("keys.json") ?? []
        statuses = load("statuses.json") ?? [:]
        history = load("history.json") ?? []
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    // MARK: Refresh

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date(); persist() }
        await withTaskGroup(of: (UUID, Result<KeyStatus, FetchError>).self) { group in
            for k in keys {
                guard let secret = Keychain.load(k.id) else {
                    statuses[k.id] = KeyStatus(health: .error, note: "Key missing from Keychain. Add it again.")
                    continue
                }
                group.addTask {
                    do { return (k.id, .success(try await Adapters.fetch(k.provider, key: secret))) }
                    catch let e as FetchError { return (k.id, .failure(e)) }
                    catch { return (k.id, .failure(.server("unknown"))) }
                }
            }
            for await (id, result) in group { apply(id, result) }
        }
    }

    private func apply(_ id: UUID, _ result: Result<KeyStatus, FetchError>) {
        switch result {
        case .success(let s):
            statuses[id] = s
            if let left = s.remaining {
                let lastAt = history.last { $0.keyID == id }?.at ?? .distantPast
                if Date().timeIntervalSince(lastAt) > 1800 { history.append(Snapshot(keyID: id, at: Date(), remaining: left)) }
            }
        case .failure(.offline):
            // Keep the last good numbers, but mark them as old.
            if var old = statuses[id] {
                old.stale = true
                old.note = "Offline. Numbers from \(Fmt.clock(old.updatedAt))."
                statuses[id] = old
            } else {
                statuses[id] = KeyStatus(health: .error, note: FetchError.offline.message)
            }
        case .failure(.limited):
            var s = statuses[id] ?? KeyStatus()
            s.health = .blocked; s.note = FetchError.limited.message; s.stale = false; s.updatedAt = Date()
            statuses[id] = s
        case .failure(let e):
            var s = statuses[id] ?? KeyStatus()
            s.health = .error; s.note = e.message; s.stale = false; s.updatedAt = Date()
            statuses[id] = s
        }
        history.removeAll { $0.at < Date().addingTimeInterval(-60 * 86400) }
    }

    // MARK: Keys

    enum AddResult {
        case added(KeyRecord, byTesting: Bool)
        case duplicate(String)
        case rejectedBy(Provider)
        case needsConsent
        case offline
        case unknown
        case failed(String)
    }

    /// Works out which provider the key belongs to (testing other providers only within `scope`),
    /// reads its credit and limits, then stores it in the Keychain.
    func add(secret raw: String, nickname: String, scope: Adapters.Scope = .hints,
             progress: @escaping @Sendable (Provider) async -> Void = { _ in }) async -> AddResult {
        let secret = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { return .unknown }
        let fp = Keychain.fingerprint(secret)
        if let dup = keys.first(where: { $0.fingerprint == fp }) { return .duplicate(dup.nickname) }
        switch await Adapters.identify(secret, scope: scope, progress: progress) {
        case .found(let provider, let status, let byTesting):
            let rec = KeyRecord(id: UUID(),
                                nickname: nickname.isEmpty ? provider.display : nickname,
                                provider: provider, fingerprint: fp,
                                masked: Fmt.mask(secret), addedAt: Date())
            do { try Keychain.save(secret, for: rec.id) } catch { return .failed(error.localizedDescription) }
            keys.append(rec)
            apply(rec.id, .success(status))
            persist()
            return .added(rec, byTesting: byTesting)
        case .rejectedBy(let p): return .rejectedBy(p)
        case .needsConsent: return .needsConsent
        case .offline: return .offline
        case .unknown: return .unknown
        }
    }

    func rename(_ id: UUID, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = keys.firstIndex(where: { $0.id == id }) else { return }
        keys[i].nickname = n
        persist()
    }

    func remove(_ id: UUID) {
        Keychain.delete(id)
        keys.removeAll { $0.id == id }
        statuses[id] = nil
        history.removeAll { $0.keyID == id }
        persist()
    }

    /// "Use this": copy the key after Touch ID / password, then clear the clipboard after 60 s.
    func copyKey(_ id: UUID) async -> Bool {
        let name = keys.first { $0.id == id }?.nickname ?? "your API key"
        guard await Keychain.confirmOwner(reason: "copy the key \"\(name)\""), let secret = Keychain.load(id) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(secret, forType: .string)
        // Tell clipboard managers (including Gautham's Clipboard) this is a secret not to keep.
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pb.setString("", forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        let stamp = pb.changeCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            if pb.changeCount == stamp { pb.clearContents() }
        }
        return true
    }

    // MARK: Menu bar icon

    /// The ring mark: a template image when all is well, tinted by the worst key otherwise.
    var trayIcon: NSImage {
        switch advice.worst {
        case .low: AppMark.menuBarImage(color: .systemOrange)
        case .blocked, .error: AppMark.menuBarImage(color: .systemRed)
        default: AppMark.menuBarImage(color: nil)
        }
    }

    // MARK: Persistence (no secrets here)

    private func persist() {
        save(keys, "keys.json"); save(statuses, "statuses.json"); save(history, "history.json")
    }
    private func save<T: Encodable>(_ v: T, _ name: String) {
        try? JSONEncoder().encode(v).write(to: dir.appendingPathComponent(name), options: .atomic)
    }
    private func load<T: Decodable>(_ name: String) -> T? {
        guard let d = try? Data(contentsOf: dir.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
