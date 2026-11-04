# TokenTray

A macOS menu bar app that tells you **which AI key to use right now** and when the others come back.

Paste your API keys once. TokenTray reads each provider's credit, rate limits and reset times, recommends the key with the most room, and counts down to when the rest recover.

## Features

- **Best key now:** one recommendation with the reason, remaining credit and how long it lasts at your current pace.
- **Coming back:** live countdowns to each provider's reset, shown in your local time.
- **15 providers:** OpenRouter, DeepSeek, Moonshot, SiliconFlow (exact balances); Groq, Cerebras (live limits); Gemini, OpenAI, Anthropic, Mistral, xAI, Together, Fireworks, Hugging Face, Cohere (key check and account details; these providers don't share balances with normal keys).
- **Honest states:** rejected keys, rate limits, offline data and provider outages are told apart.
- **Native design:** macOS 26 Liquid Glass, pointer physics, Reduce Motion support. See [DESIGN.md](DESIGN.md) and `tokentray-design/stylesheet.html`.

## Privacy and security

- Keys are stored only in the macOS **Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), never on disk in plain text.
- A key is sent only to the provider its format matches. If the format is unfamiliar, you choose the provider or explicitly approve testing it against all providers' official HTTPS APIs.
- Copying a key needs Touch ID or your Mac password, and the clipboard clears after 60 seconds.
- No analytics, no accounts, no servers of our own.
- Audited with Cloudflare's [security-audit skill](https://github.com/cloudflare/security-audit-skill) (quick profile, source-only). Its one low-severity finding is fixed.

## Build

Requires macOS 14+ and Xcode 16+ (Liquid Glass needs the macOS 26 SDK and runs on macOS 26).

```bash
./build.sh --open
```

This builds `build/TokenTray.app` with Swift Package Manager, ad-hoc signs it and launches it.

Developer checks:

```bash
.build/release/TokenTray --selftest
```
