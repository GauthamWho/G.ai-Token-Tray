// G.AI TokenTray by GauthamWho. Copyright © 2026 GauthamWho. All rights reserved. See LICENSE.
import Foundation
import SwiftUI

/// Every provider TokenTray can read. Keys are identified by testing them, prefixes are only hints.
enum Provider: String, Codable, CaseIterable {
    case openRouter, deepSeek, gemini, groq, openAI, anthropic, mistral, xai,
         cerebras, together, moonshot, siliconFlow, huggingFace, fireworks, cohere

    struct Info { let name: String; let initials: String; let hex: UInt32; let prefixes: [String] }

    var info: Info {
        switch self {
        case .openRouter: Info(name: "OpenRouter", initials: "OR", hex: 0x6467F2, prefixes: ["sk-or-"])
        case .deepSeek: Info(name: "DeepSeek", initials: "DS", hex: 0x4D6BFE, prefixes: [])
        case .gemini: Info(name: "Google Gemini", initials: "G", hex: 0x3B78E7, prefixes: ["AIza", "AQ."])
        case .groq: Info(name: "Groq", initials: "GQ", hex: 0xF55036, prefixes: ["gsk_"])
        case .openAI: Info(name: "OpenAI", initials: "OA", hex: 0x10A37F, prefixes: ["sk-proj-", "sk-svcacct-", "sk-admin-"])
        case .anthropic: Info(name: "Anthropic", initials: "AN", hex: 0xC96442, prefixes: ["sk-ant-"])
        case .mistral: Info(name: "Mistral", initials: "MI", hex: 0xFA520F, prefixes: [])
        case .xai: Info(name: "xAI", initials: "X", hex: 0x111111, prefixes: ["xai-"])
        case .cerebras: Info(name: "Cerebras", initials: "CB", hex: 0xF05A28, prefixes: ["csk-"])
        case .together: Info(name: "Together AI", initials: "TG", hex: 0x0F6FFF, prefixes: ["tgp_"])
        case .moonshot: Info(name: "Moonshot (Kimi)", initials: "KM", hex: 0x1F1F1F, prefixes: [])
        case .siliconFlow: Info(name: "SiliconFlow", initials: "SF", hex: 0x7C3AED, prefixes: [])
        case .huggingFace: Info(name: "Hugging Face", initials: "HF", hex: 0xFFB000, prefixes: ["hf_"])
        case .fireworks: Info(name: "Fireworks AI", initials: "FW", hex: 0x6720FF, prefixes: ["fw_"])
        case .cohere: Info(name: "Cohere", initials: "CO", hex: 0x39594D, prefixes: [])
        }
    }
    var display: String { info.name }
    var initials: String { info.initials }
    var color: Color { Color(hex: info.hex) }

    /// Providers whose key shape matches, most specific first. Empty means "test against all".
    static func hints(for raw: String) -> [Provider] {
        let k = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let byPrefix = allCases
            .compactMap { p in p.info.prefixes.filter { k.hasPrefix($0) }.map(\.count).max().map { (p, $0) } }
            .sorted { $0.1 > $1.1 }.map(\.0)
        if !byPrefix.isEmpty { return byPrefix }
        if k.hasPrefix("sk-") {
            // Plain sk- keys: DeepSeek uses 32 hex chars; OpenAI, Moonshot and SiliconFlow also use sk-.
            let hex = k.count == 35 && k.dropFirst(3).allSatisfy(\.isHexDigit)
            return hex ? [.deepSeek, .openAI, .moonshot, .siliconFlow] : [.openAI, .moonshot, .siliconFlow, .deepSeek]
        }
        return []
    }
}

/// One usage limit a provider reports, e.g. "requests per day".
struct LimitWindow: Codable {
    var name: String
    var remaining: Double
    var limit: Double
    var resetAt: Date?
    var fraction: Double { limit > 0 ? remaining / limit : 1 }
}

/// What we store about a key. The secret itself lives only in the Keychain.
struct KeyRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var nickname: String
    var provider: Provider
    var fingerprint: String
    var masked: String
    var addedAt: Date
}

enum Health: Int, Codable, Comparable {
    case ok, low, blocked, error
    static func < (a: Health, b: Health) -> Bool { a.rawValue < b.rawValue }
}

struct KeyStatus: Codable {
    var remaining: Double?          // money left (currency below)
    var total: Double?
    var currency: String = "USD"
    var usedToday: Double?
    var usedWeek: Double?
    var resetAt: Date?
    var resetLabel: String?
    var health: Health = .ok
    var note: String = ""
    var limits: [LimitWindow] = []
    var details: [[String]] = []    // ordered [label, value] pairs from the provider
    var updatedAt: Date = Date()
    var stale: Bool = false
}

struct Snapshot: Codable {
    var keyID: UUID
    var at: Date
    var remaining: Double
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Formatting

enum Fmt {
    /// Whole number for display. Never traps on NaN, infinity or huge values from a provider.
    static func count(_ v: Double) -> String {
        guard v.isFinite, abs(v) < 1e15 else { return "—" }
        return String(Int(v.rounded(.down)))
    }

    static func money(_ v: Double?, _ code: String = "USD") -> String {
        guard let v else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        f.maximumFractionDigits = v < 10 ? 2 : 0
        f.minimumFractionDigits = v < 10 ? 2 : 0
        return f.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    static func countdown(to date: Date, now: Date = Date()) -> String {
        let t = date.timeIntervalSince(now)
        let s = t.isFinite ? Int(min(max(t, 0), 1e9)) : 0
        let d = s / 86400, h = s % 86400 / 3600, m = s % 3600 / 60, x = s % 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if m > 0 { return "\(m)m \(String(format: "%02d", x))s" }
        return "\(x)s"
    }

    static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(date) ? "jmm" : "EEE jmm")
        return f.string(from: date)
    }

    static func runway(_ days: Double?) -> String? {
        guard let days, days.isFinite, days >= 0 else { return nil }
        if days > 60 { return "lasts 60+ days" }
        if days < 1 { return "~\(max(1, Int((days * 24).rounded())))h left" }
        return "lasts ~\(Int(days.rounded())) day\(Int(days.rounded()) == 1 ? "" : "s")"
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let t = now.timeIntervalSince(date)
        let s = t.isFinite ? Int(min(max(t, -1e9), 1e9)) : 0
        if s < 60 { return "\(max(s, 0))s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        return "\(s / 3600)h ago"
    }

    static func mask(_ key: String) -> String {
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard k.count > 12 else { return "••••" }
        let prefix = k.hasPrefix("sk-or-v1-") ? "sk-or-v1-" : String(k.prefix(4))
        return prefix + "…" + String(k.suffix(4))
    }
}
