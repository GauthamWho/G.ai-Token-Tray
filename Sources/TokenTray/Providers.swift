import Foundation

enum FetchError: Error, Equatable {
    case rejected          // 401/403 or the provider says the key is invalid
    case offline           // no network / timeout
    case limited           // 429: a rate limit is full right now
    case server(String)    // provider answered with another error

    var message: String {
        switch self {
        case .rejected: "Key rejected. Was it deleted or rotated?"
        case .offline: "Can't reach the provider. Check your internet."
        case .limited: "Rate limit hit. It frees up shortly."
        case .server(let s): "Provider error (\(s))."
        }
    }
}

/// Reads what each provider will tell a normal key: balance, limits, account details.
enum Adapters {

    // MARK: Identify any key

    enum Identification {
        case found(Provider, KeyStatus, byTesting: Bool)
        case rejectedBy(Provider)
        case needsConsent        // unfamiliar format: the user must pick a provider or approve testing all
        case offline
        case unknown
    }

    enum Scope {
        case hints               // only providers whose key format matches
        case only(Provider)      // the provider the user picked
        case all                 // every provider; only after the user approved sending the key to each
    }

    /// Sends the key only where the user expects it: its own provider by format, the provider they
    /// picked, or (with explicit approval) every provider. `progress` reports each provider as it is tried.
    static func identify(_ key: String, scope: Scope = .hints,
                         progress: @escaping @Sendable (Provider) async -> Void = { _ in }) async -> Identification {
        let hints = Provider.hints(for: key)
        let first: [Provider]
        switch scope {
        case .only(let p): first = [p]
        case .hints, .all: first = hints
        }
        if case .hints = scope, first.isEmpty { return .needsConsent }

        var rejected: Provider?
        for p in first {
            await progress(p)
            switch await attempt(p, key) {
            case .success(let s): return .found(p, s, byTesting: false)
            case .failure(.offline): return .offline
            case .failure(.rejected): rejected = rejected ?? p
            case .failure: break
            }
        }
        guard case .all = scope else { return rejected.map { .rejectedBy($0) } ?? .unknown }

        let rest = Provider.allCases.filter { !first.contains($0) }
        let hits: [(Provider, KeyStatus)] = await withTaskGroup(of: (Provider, KeyStatus?).self) { group in
            for p in rest {
                group.addTask {
                    await progress(p)
                    if case .success(let s) = await attempt(p, key) { return (p, s) }
                    return (p, nil)
                }
            }
            var out: [(Provider, KeyStatus)] = []
            for await (p, s) in group { if let s { out.append((p, s)) } }
            return out
        }
        if let hit = rest.lazy.compactMap({ p in hits.first { $0.0 == p } }).first {
            return .found(hit.0, hit.1, byTesting: true)
        }
        return .unknown
    }

    private static func attempt(_ p: Provider, _ key: String) async -> Result<KeyStatus, FetchError> {
        do { return .success(try await fetch(p, key: key)) }
        catch FetchError.limited {
            var s = KeyStatus(); s.health = .blocked; s.note = FetchError.limited.message
            return .success(s)
        }
        catch let e as FetchError { return .failure(e) }
        catch { return .failure(.server("unknown")) }
    }

    static func fetch(_ p: Provider, key: String) async throws -> KeyStatus {
        switch p {
        case .openRouter: try await openRouter(key)
        case .deepSeek: try await deepSeek(key)
        case .gemini: try await gemini(key)
        case .groq: try await probed(.groq, key, base: "https://api.groq.com/openai/v1", prefer: ["instant", "8b"])
        case .cerebras: try await probed(.cerebras, key, base: "https://api.cerebras.ai/v1", prefer: ["8b", "llama"])
        case .openAI: try await modelsOnly(key, "https://api.openai.com/v1/models",
                                           note: "Key works. OpenAI shows spend only to admin keys.")
        case .anthropic: try await modelsOnly(key, "https://api.anthropic.com/v1/models", auth: "x-api-key",
                                              extra: ["anthropic-version": "2023-06-01"],
                                              note: "Key works. Anthropic shows spend only to admin keys.")
        case .mistral: try await modelsOnly(key, "https://api.mistral.ai/v1/models",
                                            note: "Key works. Mistral doesn't share its balance through the API.")
        case .together: try await modelsOnly(key, "https://api.together.xyz/v1/models",
                                             note: "Key works. Together doesn't share its balance through the API.")
        case .fireworks: try await modelsOnly(key, "https://api.fireworks.ai/inference/v1/models",
                                              note: "Key works. Fireworks doesn't share its balance through the API.")
        case .xai: try await xai(key)
        case .moonshot: try await moonshot(key)
        case .siliconFlow: try await siliconFlow(key)
        case .huggingFace: try await huggingFace(key)
        case .cohere: try await cohere(key)
        }
    }

    // MARK: HTTP

    private static func get(_ url: String, key: String, auth: String = "Authorization",
                            extra: [String: String] = [:]) async throws -> [String: Any] {
        try await send(url, key: key, auth: auth, extra: extra).json
    }

    private static func send(_ url: String, key: String, auth: String = "Authorization", extra: [String: String] = [:],
                             body: [String: Any]? = nil) async throws -> (json: [String: Any], headers: [AnyHashable: Any]) {
        var req = URLRequest(url: URL(string: url)!)
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        req.setValue(auth == "Authorization" ? "Bearer \(k)" : k, forHTTPHeaderField: auth)
        extra.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.timeoutInterval = 12
        if let body {
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw FetchError.offline }
        let http = resp as? HTTPURLResponse
        let code = http?.statusCode ?? 0
        let text = String(data: data, encoding: .utf8) ?? ""
        if code == 401 || code == 403 || text.contains("API_KEY_INVALID") || text.contains("Incorrect API key") {
            throw FetchError.rejected
        }
        if code == 429 { throw FetchError.limited }
        guard (200..<300).contains(code),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw FetchError.server("HTTP \(code)") }
        return (obj, http?.allHeaderFields ?? [:])
    }

    /// Numbers from providers are untrusted: only finite values in a sane range get in.
    private static func num(_ v: Any?) -> Double? {
        let d: Double?
        if let n = v as? NSNumber { d = n.doubleValue } else if let s = v as? String { d = Double(s) } else { d = nil }
        guard let d, d.isFinite, abs(d) < 1e12 else { return nil }
        return d
    }

    private static func modelCount(_ j: [String: Any]) -> Int {
        ((j["data"] as? [Any]) ?? (j["models"] as? [Any]) ?? []).count
    }

    // MARK: Providers that only confirm the key

    private static func modelsOnly(_ key: String, _ url: String, auth: String = "Authorization",
                                   extra: [String: String] = [:], note: String) async throws -> KeyStatus {
        let j = try await get(url, key: key, auth: auth, extra: extra)
        let n = modelCount(j)
        guard n > 0 else { throw FetchError.server("no models") }
        var s = KeyStatus()
        s.note = note
        s.details = [["Models available", "\(n)"], ["Balance", "Not shared with normal keys"]]
        return s
    }

    // MARK: OpenRouter

    static func openRouter(_ key: String) async throws -> KeyStatus {
        let k = try await get("https://openrouter.ai/api/v1/key", key: key)
        guard let d = k["data"] as? [String: Any] else { throw FetchError.server("unexpected reply") }
        var s = KeyStatus()
        let usage = num(d["usage"]) ?? 0
        if let cap = num(d["limit"]), let left = num(d["limit_remaining"]) { s.remaining = left; s.total = cap }
        if let c = try? await get("https://openrouter.ai/api/v1/credits", key: key),
           let cd = c["data"] as? [String: Any],
           let total = num(cd["total_credits"]), let used = num(cd["total_usage"]) {
            let left = total - used
            if s.remaining == nil || left < s.remaining! { s.remaining = left; s.total = total }
            s.details.append(["Account credit", Fmt.money(total)])
        }
        s.usedToday = num(d["usage_daily"])
        s.usedWeek = num(d["usage_weekly"])
        if let r = d["limit_reset"] as? String, let at = nextReset(r) { s.resetAt = at; s.resetLabel = "\(r) spend cap resets" }
        let free = (d["is_free_tier"] as? Bool) ?? false
        let freeDaily = (s.total ?? 0) >= 10 ? 1000 : 50
        if let label = d["label"] as? String, !label.isEmpty { s.details.append(["Label", label]) }
        s.details.append(["Tier", free ? "Free (never bought credits)" : "Paid"])
        s.details.append(["Free models", "\(freeDaily) requests/day"])
        s.details.append(["Used today", Fmt.money(s.usedToday)])
        s.details.append(["Used this week", Fmt.money(s.usedWeek)])
        s.details.append(["Used in total", Fmt.money(usage)])
        if let cap = num(d["limit"]) { s.details.append(["Key spend cap", Fmt.money(cap)]) }
        if let left = s.remaining, left <= 0 {
            s.health = .blocked; s.note = "No credit left. Free models still work."
        } else if s.remaining == nil {
            s.note = "Free models only · \(freeDaily) requests/day"
        }
        return s
    }

    static func nextReset(_ kind: String, now: Date = Date()) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        switch kind {
        case "daily": return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))
        case "weekly": return cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, weekday: 2), matchingPolicy: .nextTime)
        case "monthly": return cal.nextDate(after: now, matching: DateComponents(day: 1, hour: 0, minute: 0), matchingPolicy: .nextTime)
        default: return nil
        }
    }

    // MARK: DeepSeek

    static func deepSeek(_ key: String) async throws -> KeyStatus {
        let j = try await get("https://api.deepseek.com/user/balance", key: key)
        guard let infos = j["balance_infos"] as? [[String: Any]] else { throw FetchError.server("unexpected reply") }
        let pick = infos.first { ($0["currency"] as? String) == "USD" } ?? infos.first
        var s = KeyStatus()
        s.currency = pick?["currency"] as? String ?? "USD"
        s.remaining = num(pick?["total_balance"]) ?? 0
        let available = (j["is_available"] as? Bool) ?? false
        s.details = [["Can make calls", available ? "Yes" : "No"],
                     ["Topped up", Fmt.money(num(pick?["topped_up_balance"]), s.currency)],
                     ["Granted (free)", Fmt.money(num(pick?["granted_balance"]), s.currency)]]
        if !available || (s.remaining ?? 0) <= 0 { s.health = .blocked; s.note = "Balance is empty." }
        return s
    }

    // MARK: Google Gemini

    static func gemini(_ key: String) async throws -> KeyStatus {
        let j = try await get("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200",
                              key: key, auth: "x-goog-api-key")
        let models = (j["models"] as? [[String: Any]]) ?? []
        guard !models.isEmpty else { throw FetchError.server("no models") }
        let names = models.compactMap { ($0["name"] as? String)?.replacingOccurrences(of: "models/", with: "") }
        let best = names.filter { $0.hasPrefix("gemini") && !$0.contains("embedding") }.sorted().last ?? "—"
        var s = KeyStatus()
        s.note = "Key works. Google doesn't share usage or credit."
        s.details = [["Models available", "\(models.count)"],
                     ["Newest Gemini model", best],
                     ["Free tier limits", "Shown only in Google AI Studio"]]
        return s
    }

    // MARK: Groq and Cerebras: limits arrive as headers on a 1-token request, sent at most once an hour

    private static let probeLock = NSLock()
    private static var probes: [String: (at: Date, status: KeyStatus)] = [:]

    private static func probed(_ p: Provider, _ key: String, base: String, prefer: [String]) async throws -> KeyStatus {
        let list = try await get("\(base)/models", key: key)
        let ids = (list["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        guard !ids.isEmpty else { throw FetchError.server("no models") }
        let cacheKey = p.rawValue + Keychain.fingerprint(key)
        if let cached = probeLock.withLock({ probes[cacheKey] }), Date().timeIntervalSince(cached.at) < 3600 {
            return cached.status
        }
        let model = prefer.lazy.compactMap { w in ids.first { $0.contains(w) } }.first ?? ids[0]
        var s = KeyStatus()
        do {
            let h = try await send("\(base)/chat/completions", key: key,
                                   body: ["model": model, "max_tokens": 1,
                                          "messages": [["role": "user", "content": "hi"]]]).headers
            s.limits = limits(from: h)
        } catch FetchError.limited {
            s.health = .blocked; s.note = FetchError.limited.message
        }
        for w in s.limits { s.details.append([w.name.capitalized, "\(Fmt.count(w.remaining)) of \(Fmt.count(w.limit)) left"]) }
        s.details.append(["Models available", "\(ids.count)"])
        if let day = s.limits.first(where: { $0.name.contains("today") }), day.remaining <= 0 {
            s.health = .blocked; s.note = "Daily requests used up."; s.resetAt = day.resetAt; s.resetLabel = "daily requests reset"
        }
        if let tpm = s.limits.first(where: { $0.name.hasPrefix("tokens") && $0.name.contains("minute") })?.limit, tpm < 20000 {
            s.details.append(["Heads-up", "\(Fmt.count(tpm)) tokens/minute is too small for coding agents like OpenCode"])
        }
        if s.limits.isEmpty && s.note.isEmpty { s.note = "Key works. No limit headers were returned." }
        probeLock.withLock { probes[cacheKey] = (Date(), s) }
        return s
    }

    /// Pairs `x-ratelimit-limit-<x>` with `-remaining-<x>` and `-reset-<x>` (Groq, Cerebras, OpenAI style).
    static func limits(from headers: [AnyHashable: Any]) -> [LimitWindow] {
        var h: [String: String] = [:]
        for (k, v) in headers { if let k = k as? String, let v = v as? String { h[k.lowercased()] = v } }
        let suffixes = h.keys.compactMap { $0.hasPrefix("x-ratelimit-limit-") ? String($0.dropFirst(18)) : nil }.sorted()
        return suffixes.compactMap { sfx in
            guard let lim = h["x-ratelimit-limit-\(sfx)"].flatMap(Double.init),
                  let rem = h["x-ratelimit-remaining-\(sfx)"].flatMap(Double.init),
                  lim.isFinite, rem.isFinite, lim >= 0, rem >= 0, lim < 1e12, rem < 1e12 else { return nil }
            let reset = h["x-ratelimit-reset-\(sfx)"]
                .flatMap { Double($0) ?? duration($0) }
                .flatMap { $0.isFinite && $0 >= 0 && $0 < 400 * 86400 ? Date().addingTimeInterval($0) : nil }
            return LimitWindow(name: limitName(sfx), remaining: rem, limit: lim, resetAt: reset)
        }
    }

    static func limitName(_ sfx: String) -> String {
        switch sfx {
        case "requests": "requests today"
        case "tokens": "tokens this minute"
        default: sfx.replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: " day", with: " today")
                    .replacingOccurrences(of: " minute", with: " this minute")
                    .replacingOccurrences(of: " hour", with: " this hour")
        }
    }

    /// Reset times look like "2m59.56s", "7.66s", "1h2m3s" or "500ms".
    static func duration(_ raw: String) -> TimeInterval? {
        var total = 0.0, number = ""
        for c in raw.replacingOccurrences(of: "ms", with: "x") {
            if c.isNumber || c == "." { number.append(c); continue }
            guard let v = Double(number) else { return nil }
            switch c { case "h": total += v * 3600; case "m": total += v * 60; case "s": total += v; case "x": total += v / 1000; default: return nil }
            number = ""
        }
        return number.isEmpty ? total : nil
    }

    // MARK: xAI

    static func xai(_ key: String) async throws -> KeyStatus {
        let j = try await get("https://api.x.ai/v1/api-key", key: key)
        guard j["api_key_id"] != nil || j["name"] != nil else { throw FetchError.server("unexpected reply") }
        var s = KeyStatus()
        let blocked = (j["api_key_blocked"] as? Bool ?? false) || (j["team_blocked"] as? Bool ?? false)
        let disabled = j["api_key_disabled"] as? Bool ?? false
        s.details = [["Key name", j["name"] as? String ?? "—"],
                     ["Status", blocked ? "Blocked" : disabled ? "Disabled" : "Active"],
                     ["Balance", "Shown only in the xAI console"]]
        if blocked || disabled { s.health = .blocked; s.note = blocked ? "Key or team is blocked." : "Key is disabled." }
        else { s.note = "Key works. xAI doesn't share credit through the API." }
        return s
    }

    // MARK: Moonshot (Kimi)

    static func moonshot(_ key: String) async throws -> KeyStatus {
        for (host, cur) in [("https://api.moonshot.ai", "USD"), ("https://api.moonshot.cn", "CNY")] {
            guard let j = try? await get("\(host)/v1/users/me/balance", key: key),
                  let d = j["data"] as? [String: Any], let avail = num(d["available_balance"]) else { continue }
            var s = KeyStatus()
            s.currency = cur; s.remaining = avail
            s.details = [["Cash", Fmt.money(num(d["cash_balance"]), cur)],
                         ["Vouchers", Fmt.money(num(d["voucher_balance"]), cur)]]
            if avail <= 0 { s.health = .blocked; s.note = "Balance is empty." }
            return s
        }
        throw FetchError.rejected
    }

    // MARK: SiliconFlow

    static func siliconFlow(_ key: String) async throws -> KeyStatus {
        let j = try await get("https://api.siliconflow.cn/v1/user/info", key: key)
        guard let d = j["data"] as? [String: Any], let total = num(d["totalBalance"]) else { throw FetchError.server("unexpected reply") }
        var s = KeyStatus()
        s.currency = "CNY"; s.remaining = total
        s.details = [["Account", d["name"] as? String ?? "—"],
                     ["Free balance", Fmt.money(num(d["balance"]), "CNY")],
                     ["Paid balance", Fmt.money(num(d["chargeBalance"]), "CNY")]]
        if total <= 0 { s.health = .blocked; s.note = "Balance is empty." }
        return s
    }

    // MARK: Hugging Face

    static func huggingFace(_ key: String) async throws -> KeyStatus {
        let j = try await get("https://huggingface.co/api/whoami-v2", key: key)
        guard let name = j["name"] as? String else { throw FetchError.server("unexpected reply") }
        let token = (j["auth"] as? [String: Any])?["accessToken"] as? [String: Any]
        var s = KeyStatus()
        s.note = "Token works. Inference credits are shown only on huggingface.co."
        s.details = [["Account", name],
                     ["Plan", (j["isPro"] as? Bool ?? false) ? "PRO" : "Free"],
                     ["Token name", token?["displayName"] as? String ?? "—"],
                     ["Permission", token?["role"] as? String ?? "—"]]
        return s
    }

    // MARK: Cohere

    static func cohere(_ key: String) async throws -> KeyStatus {
        let j = try await send("https://api.cohere.com/v1/check-api-key", key: key, body: [:]).json
        guard j["valid"] as? Bool == true else { throw FetchError.rejected }
        var s = KeyStatus()
        s.note = "Key works. Cohere doesn't share usage through the API."
        s.details = [["Valid", "Yes"], ["Balance", "Shown only in the Cohere dashboard"]]
        return s
    }
}
