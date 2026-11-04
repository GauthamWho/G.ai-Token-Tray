<div align="center">

<img src="docs/readme/logo.png" width="120" alt="G.ai Token Tray logo">

# G.ai Token Tray

**Which AI key should I use right now?**
A tiny Mac menu bar app by **GauthamWho**.

<img src="https://img.shields.io/badge/macOS-14%2B-1F6BFF?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+">
<img src="https://img.shields.io/badge/Liquid%20Glass-macOS%2026-0A3DCC?style=flat-square" alt="Liquid Glass">
<img src="https://img.shields.io/badge/providers-15-8FCCFF?style=flat-square" alt="15 providers">
<img src="https://img.shields.io/badge/free%20to%20use-%C2%A9%20GauthamWho-1d1d1f?style=flat-square" alt="Free to use, © GauthamWho">

<br><br>

<img src="docs/readme/hero.svg" width="100%" alt="G.ai Token Tray: the best AI key right now, with credit left and reset countdowns">

</div>

---

## 😩 → 😌 The problem it solves

<img src="docs/readme/problem.svg" width="100%" alt="Without: errors and guessing. With: one glance shows the best key">

> You use free and paid AI keys. One runs out mid-task. Which one still has credit? When does the other come back?
> **G.ai Token Tray answers that in one glance, from your menu bar.**

---

## 👀 What you see

<table>
<tr>
<td align="center"><img src="docs/readme/panel-light.png" width="380" alt="Panel in light mode"><br><sub>Light</sub></td>
<td align="center"><img src="docs/readme/panel-dark.png" width="380" alt="Panel in dark mode"><br><sub>Dark</sub></td>
</tr>
</table>

| Look at | It means |
|:--|:--|
| 🟩 **Best right now** | Use this key. Big number = credit or requests left. |
| ⏱ **Coming back** | A key that's paused, and the countdown until it works again. |
| 🟠 dot | Running low. |
| 🔴 dot / red line | Broken or empty. Fix or remove it. |
| **Use** button | Copies the key (Touch ID). Clipboard clears after 60 s. |

---

## ⚙️ How it works

<img src="docs/readme/how-it-works.svg" width="100%" alt="Paste a key, locked in Keychain, ask its provider, pick the best key, glance at the menu bar">

---

## 📦 Install (3 steps)

<img src="docs/readme/install.svg" width="100%" alt="1 get the code, 2 build and open, 3 click the G in the menu bar">

```bash
git clone https://github.com/GauthamWho/G.ai-Token-Tray.git
```

```bash
cd G.ai-Token-Tray && ./build.sh --open
```

Needs a Mac on **macOS 14+** with **Xcode** installed. Liquid Glass shows on macOS 26.
The **G** appears in your menu bar, top right. 🎉

---

## 🔑 Add a key

<div align="center">
<img src="docs/readme/add-key.gif" width="420" alt="Paste a key, it is checked with its provider, credit appears">
</div>

1. Click **G** → **+ Add key**
2. Paste your key → **Check & add**
3. Done. Credit, limits and resets appear.

Unfamiliar key format? You pick the provider, or tap **Test with all providers**. Your key never goes anywhere you didn't choose.

---

## 🌐 Works with 15 providers

<img src="docs/readme/providers.svg" width="100%" alt="Exact credit: OpenRouter, DeepSeek, Moonshot, SiliconFlow. Live limits: Groq, Cerebras. Key check: the rest">

---

## 🛡️ Private by design

| | |
|:--:|:--|
| 🔐 | Keys live only in your Mac's **Keychain**. Never in plain files. |
| 🎯 | A key goes **only to its own provider**. Nothing else without your OK. |
| 👆 | Copying a key needs **Touch ID** or your password. |
| 🚫 | No accounts, no tracking, no servers of mine. |
| ✅ | Checked with Cloudflare's [security-audit skill](https://github.com/cloudflare/security-audit-skill). Its one finding is fixed. |

---

## ✨ Feels premium

Liquid Glass panel · cursor-following light · a hero card that leans toward your pointer · rolling numbers · live countdowns · readable candy-pink accent shared with [Gautham's Clipboard](https://github.com/GauthamWho/gs-clipboard) · light and dark mode · respects **Reduce Motion**.

**Keyboard:** ↩ copies the recommended key (Touch ID) · ⌘R checks all keys · ⌘N adds a key · ⌘Q quits.

---

## 💡 Why I built this

I kept hitting "free usage limit reached" in the middle of work, then guessing which key still had credit. I wanted one glance that tells me what to use, without opening five dashboards. So I built it.

**— GauthamWho**

---

## 🙋 Ideas? Problems? Tell me

<div align="center">

[![Open an issue](https://img.shields.io/badge/💬%20Suggest%20an%20improvement-Open%20an%20issue-1F6BFF?style=for-the-badge)](https://github.com/GauthamWho/G.ai-Token-Tray/issues/new)
&nbsp;
[![GauthamWho on GitHub](https://img.shields.io/badge/GitHub-GauthamWho-1d1d1f?style=for-the-badge&logo=github)](https://github.com/GauthamWho)

</div>

---

## © License

**Free to use. Not free to sell or copy.**

| ✅ You can | ❌ You can't |
|:--|:--|
| Download, build and use it, free | Sell it or charge for it |
| Read the code | Re-upload or redistribute it |
| Share the link to this repo | Build your own product on this code |

Copyright © 2026 **GauthamWho**. All rights reserved. Full terms: [LICENSE](LICENSE).

<details>
<summary>For developers</summary>

```bash
.build/release/TokenTray --selftest
```

Design system: [DESIGN.md](DESIGN.md) · style sheet: `tokentray-design/stylesheet.html` · product notes: [PRODUCT.md](PRODUCT.md).
</details>
