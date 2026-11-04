# G.ai Token Tray — Mac menu bar app that tracks API key usage

Working name: **TokenTray**. Lives in the macOS menu bar (top-right, next to the clock), with an optional live number like `28%` beside the icon.
Answers four questions for every API key: **How much did I use? How much is left? How fast am I burning it? When will it run out?**

---

## 1. The honest catch (read first)

Providers do NOT all tell you your balance. What a key can reveal depends on the provider:

| Provider | Can we read balance/usage from the key? | How |
|---|---|---|
| OpenRouter | Yes, exact | `GET /api/v1/key` (usage, limit, remaining) + `/api/v1/credits` |
| DeepSeek | Yes, balance | `GET /user/balance` |
| Moonshot / Kimi, SiliconFlow and some others | Yes, balance | their balance endpoints |
| OpenAI | Only with an **Admin key** | Usage + Costs API; normal keys only show rate-limit headers |
| Anthropic | Only with an **Admin key** | Usage & Cost Admin API; normal keys only show rate-limit headers |
| Groq | Rate limits only | `x-ratelimit-remaining-*` response headers |
| Google Gemini | No usage API from the key | only quotas in Google Cloud console |

So TokenTray uses **4 data sources**, best one available per key:

1. **Balance API** — exact remaining money/credits (OpenRouter, DeepSeek…).
2. **Admin usage API** — exact spend if the user adds an admin key (OpenAI, Anthropic).
3. **Rate-limit probe** — a tiny call that reads "requests/tokens left this minute/day" headers (Groq, OpenAI, Anthropic).
4. **Meter mode (local proxy)** — TokenTray runs on `127.0.0.1`; the user points their tools (OpenCode, scripts, apps) at it. It forwards every request and **counts every token exactly**, for ANY provider, including Gemini. Combined with a budget the user types in ("I have $10" / "1M tokens free per day") it gives remaining + time left.

Each key card shows a small badge saying which source it uses: `Exact` / `Admin` / `Limits only` / `Metered`.

---

## 2. User flow (UX)

**First run**
1. Drag to Applications → TokenTray starts, icon appears in the menu bar, welcome popup: *"Add your first API key."*
2. User pastes a key. App **auto-detects the provider** from the prefix
   (`sk-or-` OpenRouter, `sk-ant-` Anthropic, `sk-proj-` OpenAI, `AIza` Google, `gsk_` Groq; ambiguous `sk-` → test call against DeepSeek/OpenAI/etc.).
3. App validates it with one cheap call → shows ✅ *"OpenRouter key — exact balance available"* or ⚠️ *"Gemini key — Google doesn't share usage. Turn on Meter mode and set a budget?"*
4. User gives it a nickname ("Work OpenRouter") and optional monthly budget/reset day.
5. Done → popover opens showing the card. Add more keys with **+**.

**Every day**
- Glance at the menu bar icon: a small ring that fills and changes colour for the key closest to empty (green > 50%, amber 20–50%, red < 20%).
- Hover → tooltip: *"Work OpenRouter: $3.20 left · ~4 days"*.
- Click → **popover panel** hanging from the icon (like the macOS Wi-Fi / Control Centre menus).
- Right-click / Option-click → menu: Refresh now · Add key · Settings · Pause meter · Quit.
- macOS notifications at 50 % / 80 % / 95 % used, when a rate limit is hit, or when a key becomes invalid.

---

## 3. Screens (UI)

**A. Popover panel** (≈360 × 520, opens below the menu bar icon) — **LOCKED: design G1 "Advisor, refined"** (picked 2026-11-04; see `tokentray-design/index.html`, Round 2 tab):
  1. **Best to use right now** — one recommended key, short stats, "Use this" button.
  2. **Why** — one line on what is low (e.g. "Claude will run out before it resets. Gemini has 38 requests left.").
  3. **Coming back** — the other keys with what resets, a live countdown and the local reset time.
  4. Footer: Add key · Switch helper · Settings.
  - **LOCKED look: L11 "Compact"** (picked 2026-11-04, Round 3 tab): white popover, 12 px Geist/SF type, tight 7×12 px rows, 10 px corners, indigo accent `#5b5bd6`, green `#1e8e3e` / amber `#b25e00` / red `#c4281c` for status, light grey lines `#eceef1`. Menu bar shows **icon only**, tinted by the worst status. Fits more keys without scrolling. Dark mode = same layout with dark surfaces.

  Earlier idea for the panel (kept for the detail window):
- Header: "G.ai Token Tray" · total spent today across all keys · refresh button · last-updated time.
- List of **key cards**, sorted by "runs out soonest":
  - Provider logo + nickname + masked key (`sk-or-…8f2a`) + source badge.
  - Big number: **remaining** ($ or tokens).
  - Progress bar: used vs total.
  - Row: *Burned today* · *Burn rate (per day)* · ***Runs out in ~X days***.
  - If limits-only: "Requests left this minute: 28/30 · Tokens left today: 410k/500k".
- Footer: **+ Add key** · Settings.

**B. Key detail window** (click a card)
- 30-day usage chart (bar per day), toggle $ / tokens.
- Breakdown by model (table: model, requests, input tokens, output tokens, cost).
- Limits section (rate limits, plan tier, reset time).
- Forecast: "At this week's pace, $3.20 lasts until **Sat 8 Nov**."
- Key info: provider, created/added date, all details the provider returns (label, tier, is_free_tier, etc.).
- Actions: rename · set budget · copy masked key · re-check · delete key.

**C. Add-key dialog** — paste box, detected provider, validation result, nickname, budget, reset day.

**D. Settings** — refresh interval (default 5 min), open at login, currency, alert thresholds, Meter mode on/off + port, dark/light (follows macOS), show number in menu bar, export history CSV.

---

## 4. The maths

- **Used** = from provider API, or sum of metered tokens/cost.
- **Remaining** = provider balance, or budget − used.
- **Burn rate** = weighted average of the last 7 days (recent days count more), so one heavy day doesn't wreck the forecast.
- **Time left** = remaining ÷ burn rate → shown as hours/days and as a date.
- Cost for metered tokens = tokens × model price from a bundled price table (updatable, user can override).

---

## 5. Security (non-negotiable)

- Keys stored in the **macOS Keychain**, never in plain files, never in logs. Showing/copying a full key asks for Touch ID.
- Always shown masked; full key only on explicit "copy".
- No cloud, no account, no telemetry — everything stays on the Mac.
- Meter proxy binds to `127.0.0.1` only.
- Only calls the official provider endpoints.

---

## 6. Tech stack (Mac)

- **Swift + SwiftUI**, using `MenuBarExtra` for the menu bar popover: native look, tiny (~5 MB), low battery use, Apple Silicon + Intel.
- Keys in **Keychain** (Security framework), Touch ID via LocalAuthentication.
- Notifications via UserNotifications; open-at-login via `SMAppService`.
- Storage: SQLite (GRDB) or SwiftData for usage history.
- Charts: **Swift Charts** (built in).
- Meter mode proxy: small local HTTP server (SwiftNIO / Network framework) on `127.0.0.1`.
- Provider **adapters**: one Swift file per provider with the same protocol
  `detect() · validate() · fetchUsage() · fetchLimits() · details()`.
- Claude / ChatGPT **plans** (5-hour session + weekly caps) are a second adapter type: they read the plan's usage (e.g. Claude Code's local usage data or the signed-in account), not an API key. Must be verified per provider before building.
- Later, if Windows is wanted too: same design in Tauri.
---

## 7. Build steps (in order)

1. **Skeleton** — SwiftUI menu bar app, icon, empty popover, Keychain storage, add/delete key.
2. **First adapters** — OpenRouter + DeepSeek (exact balances, easiest wins) → working cards.
3. **History + forecast** — SQLite snapshots every refresh, burn rate, "runs out in".
4. **Detail window** — charts, model breakdown, all key details.
5. **More adapters** — OpenAI/Anthropic admin, Groq/OpenAI/Anthropic limit probes, Gemini (meter-only).
6. **Meter mode** — local OpenAI-compatible proxy that counts tokens per key/model.
7. **Alerts + settings** — toasts, thresholds, autostart, export.
8. **Package** — signed + notarised `.dmg`, auto-update (Sparkle), test on macOS 14+ (Apple Silicon + Intel).

**MVP = steps 1–3** (tray + OpenRouter/DeepSeek + forecast) — usable in a few days.

---

## 8. Open questions for your friend

- Which providers does he actually use? (decides which adapters come first)
- Does he want money ($), tokens, or both on the cards?
- Will he route his tools through Meter mode, or only check balances?
- Which macOS version? Apple Silicon only, or Intel too?
