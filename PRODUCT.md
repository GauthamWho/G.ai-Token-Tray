# TokenTray

## What it is
A macOS menu bar app that answers one question at a glance: **which AI key should I use right now, and when do the others come back?** It tracks every API key and AI plan the user owns: money or tokens left, every limit window (per minute, per day, 5-hour session, weekly, credit), reset times, and how long the balance lasts at the current pace.

## Who it is for
Developers and heavy AI users who juggle several providers (OpenRouter, DeepSeek, OpenAI, Anthropic, Gemini, Groq, Claude/ChatGPT plans), often mixing free tiers and small prepaid balances, and who keep hitting limits mid-work. First user: the owner's friend, on a Mac.

## Use scene
Glanced at dozens of times a day from the menu bar while coding, often mid-task after an error. The panel must be read in about two seconds. Light or dark follows macOS.

## Mode
Operate. Scanability, native Mac expectations and honesty about data quality outrank expression.

## Decisions made with the owner (2026-11-04, design rounds 1 to 3)
- Platform: macOS menu bar (not Windows tray).
- Panel layout: **G1 "Advisor, refined"**. Best key to use now, one line on why, then "coming back" with live countdowns and local reset times.
- Look: **L11 "Compact"**. See DESIGN.md.
- Menu bar: icon only, coloured by the worst status.

## Principles
- Never show an old number as if it were live. Every number says where it came from (exact from provider, counted locally, or estimated).
- Separate "your key is broken" from "the provider is down" from "you hit a limit, wait".
- Keys live only in the macOS Keychain. Nothing leaves the Mac except calls to the providers' own APIs.

## Assumptions (not yet confirmed by the owner)
- Minimum macOS 14 (Sonoma).
- 15 providers. A pasted key goes only to the provider its format matches. If the format is unfamiliar or that provider rejects it, the user picks the provider or explicitly approves testing it against all providers' official APIs (security audit 2026-11-04). Exact balances: OpenRouter, DeepSeek, Moonshot, SiliconFlow. Live limits: Groq, Cerebras. Key check + account details only: Gemini, OpenAI, Anthropic, Mistral, xAI, Together, Fireworks, Hugging Face, Cohere (those providers don't share balance with normal keys).
