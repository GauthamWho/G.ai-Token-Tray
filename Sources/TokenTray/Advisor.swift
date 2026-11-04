import Foundation

/// Everything the panel shows, derived from keys + statuses + history in one pure step.
struct Advice {
    struct Entry: Identifiable {
        let key: KeyRecord
        let status: KeyStatus?
        let runwayDays: Double?
        var id: UUID { key.id }
        var health: Health { status?.health ?? .error }
        /// True when the provider tells us how much is left, so a recommendation can be trusted.
        var knowsRoom: Bool { status?.remaining != nil || !(status?.limits.isEmpty ?? true) }
    }

    var best: Entry?
    var why: String
    var comingBack: [(entry: Entry, at: Date, label: String)]
    var others: [Entry]
    var worst: Health?
}

enum Advisor {
    /// Money spent per day, from the provider's own weekly figure when it has one,
    /// otherwise from drops in the balance we recorded over the last 7 days.
    static func burnPerDay(_ s: KeyStatus?, history: [Snapshot]) -> Double? {
        if let week = s?.usedWeek, week > 0 { return max(week / 7, s?.usedToday ?? 0) }
        let recent = history.filter { $0.at > Date().addingTimeInterval(-7 * 86400) }.sorted { $0.at < $1.at }
        guard let first = recent.first, let last = recent.last,
              last.at.timeIntervalSince(first.at) > 6 * 3600 else { return nil }
        var spent = 0.0
        for (a, b) in zip(recent, recent.dropFirst()) where b.remaining < a.remaining { spent += a.remaining - b.remaining }
        let days = last.at.timeIntervalSince(first.at) / 86400
        return spent > 0 ? spent / days : nil
    }

    static func advise(keys: [KeyRecord], statuses: [UUID: KeyStatus], history: [Snapshot]) -> Advice {
        let entries: [Advice.Entry] = keys.map { k in
            let s = statuses[k.id]
            var runway: Double? = nil
            if let left = s?.remaining, left > 0,
               let burn = burnPerDay(s, history: history.filter { $0.keyID == k.id }), burn > 0 {
                runway = left / burn
            }
            return Advice.Entry(key: k, status: s.map { adjusted($0, runway: runway) }, runwayDays: runway)
        }

        // Usable keys ranked: healthy first, then the longest runway (unknown runway sits between).
        let usable = entries.filter { $0.health <= .low && !($0.status?.stale ?? false) }
        let best = usable.sorted { a, b in
            if a.health != b.health { return a.health < b.health }
            if a.knowsRoom != b.knowsRoom { return a.knowsRoom }
            return (a.runwayDays ?? 30) > (b.runwayDays ?? 30)
        }.first

        let rest = entries.filter { $0.id != best?.id }
        let comingBack = rest.compactMap { e -> (Advice.Entry, Date, String)? in
            guard e.health != .ok, let at = e.status?.resetAt, at > Date() else { return nil }
            return (e, at, e.status?.resetLabel ?? "resets")
        }.sorted { $0.1 < $1.1 }
        let others = rest.filter { e in !comingBack.contains { $0.0.id == e.id } }

        return Advice(best: best,
                      why: whyLine(best: best, rest: rest),
                      comingBack: comingBack.map { (entry: $0.0, at: $0.1, label: $0.2) },
                      others: others,
                      worst: entries.map(\.health).max())
    }

    /// Low runway turns a healthy key amber.
    private static func adjusted(_ s: KeyStatus, runway: Double?) -> KeyStatus {
        var s = s
        if s.health == .ok, let r = runway, r < 2 { s.health = .low; s.note = "Runs out in under 2 days at this pace." }
        if s.health == .ok, let w = s.limits.min(by: { $0.fraction < $1.fraction }), w.fraction < 0.15 {
            s.health = .low; s.note = "Only \(Fmt.count(w.remaining)) \(w.name) left."
            if s.resetAt == nil { s.resetAt = w.resetAt; s.resetLabel = "\(w.name) reset" }
        }
        if s.health == .ok, let left = s.remaining, let total = s.total, total > 0, left / total < 0.15 {
            s.health = .low; s.note = "Only \(Fmt.count(left / total * 100))% left."
        }
        return s
    }

    private static func whyLine(best: Advice.Entry?, rest: [Advice.Entry]) -> String {
        let trouble = rest.filter { $0.health != .ok }.sorted { $0.health > $1.health }.prefix(2)
        if best == nil { return rest.isEmpty ? "Add a key to get started." : "No key has room right now." }
        if trouble.isEmpty { return rest.isEmpty ? "Your only key. Add more to compare." : "Everything else is fine too." }
        return trouble.map { e -> String in
            let n = e.key.nickname
            switch e.health {
            case .error: return e.status?.stale == true ? "\(n) is offline." : "\(n) needs fixing."
            case .blocked:
                if let at = e.status?.resetAt { return "\(n) is capped until \(Fmt.clock(at))." }
                return "\(n) is out of credit."
            case .low: return "\(n) is running low."
            case .ok: return ""
            }
        }.joined(separator: " ")
    }
}
