# TokenTray design system: "Quiet instrument"

Visual reference: `tokentray-design/stylesheet.html`. Code: `Sources/TokenTray/DesignSystem.swift` (`DS`). Every view reads tokens from `DS`; no raw sizes or colours in views.

## Principles
- **Light, not loud.** Regular, medium and light weights only. Never bold. Big numbers are light.
- **One tint.** Indigo (`systemIndigo`) marks what you can press. Green, orange, red appear only for status.
- **Tone before colour.** Label, secondary, tertiary grey carry hierarchy.
- **8-point rhythm.** Gaps are 4, 8, 12, 16, 20. Nothing crowded, no orphan space, nothing overlapping.
- **Native material.** macOS 26 Liquid Glass (`glassEffect`, `.glass` buttons); `regularMaterial` on macOS 14–15. Semantic system colours, so dark mode and Increase Contrast adapt.

## Type (San Francisco)
| Role | Spec |
|---|---|
| Hero figure | SF Pro Rounded 30, Light, tracking −0.5, tabular |
| Title | 15 Medium |
| Name | 13 Medium |
| Row figure | SF Pro Rounded 13 Medium, tabular |
| Body | 12 Regular |
| Meta | 11 Regular, secondary |
| Overline | 11 Medium, uppercase, +0.7 tracking, tertiary |

## Shape
Tile 7 · row 10 · card 16 · panel 20 · controls capsule. Hairlines 0.5 pt `separatorColor`, used once (above the footer).

## Components
- **App mark:** ring gauge (open arc, dot, needle), drawn as a shape. Header in tint.
- **Provider tile:** monogram on a 13% wash of the provider colour (22% in dark, lighter text).
- **Hero card:** overline + status, tile + name + masked key + Use (only primary button), hero figure + unit + runway, 3 pt meter, one-line reason. Green-tinted glass.
- **Row:** tile, name, meta line (red only when broken), trailing figure or countdown with a 6 pt status dot when not healthy.
- **Details:** meters, then a two-column label/value grid, then Copy / Remove capsules.

## Motion and physics
- Focal moment: add-key scan; provider tiles light up as tested; Dock-style magnification under the cursor; the match grows into the result.
- Pointer: glow follows the cursor on the hero and rows; hero tilts toward the cursor and can be flung (rubber-band, springs back with release velocity); tiles are magnetic.
- Feedback: rolling numbers, rotating refresh, Use → checkmark with haptic, one-shot status bounces.
- Spring response 0.42 / damping 0.88; quick 0.16 s; stagger 35 ms capped at 0.25 s. Reduce Motion disables all of it.
