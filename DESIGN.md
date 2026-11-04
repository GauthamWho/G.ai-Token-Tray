# G.ai Token Tray design system: "Quiet instrument" (Clipboard-sibling edition, 2026-11-05)

Visual reference: `tokentray-design/stylesheet.html`. Code: `Sources/TokenTray/DesignSystem.swift` (`DS`). Every view reads tokens from `DS`; no raw sizes or colours in views.

## Principles
- **Light, not loud.** Regular, medium and light weights only. Never bold. Big numbers are light.
- **One tint.** Candy pink, shared with Gautham's Clipboard: text and accents `tint` (#FF70B3 dark / #CC1A73 light), button fills `tintFill` (#CC1A73, white label ≈5.4:1). Green, orange, red appear only for status; error text uses `criticalText` (#C8102E light).
- **Tone before colour.** Label and the readable `meta` grey (white 56% / #5C5C61, ≥4.5:1) carry hierarchy. Tertiary grey is never used for text.
- **8-point rhythm.** Gaps are 4, 8, 12, 16, 20. Nothing crowded, no orphan space, nothing overlapping.
- **Native material.** macOS 26 Liquid Glass (`glassEffect`, `.glass` buttons); `regularMaterial` on macOS 14–15. Semantic system colours, so dark mode and Increase Contrast adapt.

## Type (San Francisco)
| Role | Spec |
|---|---|
| Hero figure | SF Pro Rounded 35, Light, tracking −0.5, tabular |
| Title | 15 Medium |
| Name | 13 Medium |
| Row figure | SF Pro Rounded 13 Medium, tabular |
| Body | 12 Regular |
| Meta | 11 Regular, `meta` grey |
| Overline | 11 Medium, uppercase, +0.7 tracking, `meta` grey |

## Shape
Tile 7 · row 10 · card 16 · panel 20 · controls capsule. Hairlines 0.5 pt `separatorColor`, used once (above the footer).

## Components
- **App mark:** ring gauge (open arc, dot, needle), drawn as a shape. Header in tint.
- **Provider tile:** monogram on a 13% wash of the provider colour (22% in dark, lighter text).
- **Hero card:** neutral glass, overline "Use this now" + status, tile + name + masked key + Use (only primary button), hero figure + unit + runway, 3 pt meter, one-line reason. Green-tinted glass.
- **Row:** tile, name, meta line (red only when broken), trailing figure or countdown with a 6 pt status dot when not healthy.
- **Details:** meters, then a two-column label/value grid, then Copy / Remove capsules.

## Motion and physics
- Focal moment: add-key scan; provider tiles light up as tested; Dock-style magnification under the cursor; the match grows into the result.
- Pointer: glow follows the cursor on the hero and rows; hero tilts toward the cursor and can be flung (rubber-band, springs back with release velocity); tiles are magnetic.
- Feedback: rolling numbers, rotating refresh, Use → checkmark with haptic, one-shot status bounces.
- Spring response 0.42 / damping 0.88; quick 0.16 s; stagger 35 ms capped at 0.25 s. Reduce Motion disables all of it.

## Clipboard-sibling edition (approved 2026-11-05)
- Chosen from `tokentray-design/redesign-picker.html`, direction #1.
- One left and one right edge for header, hero content, rows and footer (8 pt inset; hero content 16 pt inside the card).
- Hero card: neutral glass (no green tint), white pointer light, gentle tilt only (no fling). Rows: white pointer light, lift 1 pt on hover (off under Reduce Motion).
- Keyboard: ↩ copies the recommended key (Touch ID), ⌘R refresh, ⌘N add key, ⌘Q quit.
- Provider monograms are darkened 38% in light mode so they read (≥4.5:1). Gemini's tile is "GM" so it never reads as the app's G.
