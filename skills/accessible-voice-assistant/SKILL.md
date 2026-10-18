---
name: "accessible-voice-assistant"
description: "Accessible voice assistant with multilingual speech synthesis (English/Spanish/auto-detect), pure white text (#ffffff), and large print for low-vision users in dark themes."
---

# Accessible Voice Assistant Skill — CrowKit 🦅

This skill provides accessible audio assistance with multilingual Text-to-Speech (via Web Speech API supporting auto-detection, English, Spanish, French, German, and Portuguese), volume controls (`0%` to `100%`), voice pitch/timbre profiles (`Natural`, `Deep / Low`, `Clear / High`, `Calm / Warm` + native system voices), dynamic font sizing (`16px` to `42px`), and high-contrast visual styling (pure white text `#ffffff` over dark surfaces `#0b1120`) for low-vision and dark theme users.

---

## 📌 Accessible Formatting Rules for Chat

1. **Large & Hierarchical Typography:**
   - Use `##` headings for main concepts and decision options so that chat renderers display larger and bolder fonts.
   - Avoid long continuous text blocks or multi-column tables; prefer short, direct numbered lists.
2. **High-Contrast Dark Theme:**
   - In all HTML artifacts or inline widgets (`<agent-embed>`), use **pure white text (`#ffffff`)** over a dark background (`#0b1120` / `#111827`) with cyan borders (`#38bdf8`) and yellow focus rings (`#facc15`).
   - Keep a default base font size of **`24px`** (or adjustable between `16px` and `42px`).

---

## 🔊 Workflow for Inserting the Voice Player into Chat

1. **Copy and Update Base Template:**
   Use [resources/audio-assistant-template.html](resources/audio-assistant-template.html) as the base reference and save it to the conversation artifact directory (`<appDataDir>/brain/<conversation-id>/audio_assistant.html`) with `UserFacing: true`.
2. **Customize Speech & Reading Content (`#raw-text-source`):**
   Update the contents of `<div id="raw-text-source" style="display:none;">` with the Markdown summary of the current response in the user's language (English, Spanish, or auto-detected). The widget renders this formatted text in pure white in the expandable text drawer.
3. **Embed the Widget in the Response:**
   Include the `<agent-embed>` tag at the very start of the chat response:

```html
<agent-embed src="file:///<artifact_path>/audio_assistant.html"></agent-embed>
```

---

## ⌨️ Accessible Controls Included in the Template

- **▶️ Listen / ⏸️ Pause / ⏹️ Stop:** Compact top bar with primary speech controls.
- **🌐 Multilingual Support & Auto-detect (`#lang-select`):** Select between Auto-detect, English (US/UK), Spanish (MX/ES), French, German, Portuguese, Italian, or Japanese. Automatically filters native system voices to match the selected language.
- **📄 Collapsible Text (`#text-drawer`):** Toggle button (`📄 Text ▾`) showing or hiding the formatted response text with a 1-click Markdown copy button (`📋`).
- **⚙️ Collapsible Settings (`#settings-drawer`):** Clean and accessible drawer with:
  - **🎨 High-Contrast Themes (`#theme-select`):** 16 themes (11 DaisyUI dark/vibrant palettes + 5 developer favorites: Nord, Tokyo Night, Monokai, Solarized Dark, Black OLED).
  - **🔘 Button Mode:** Supports icons-only or icons + text labels.
  - **📐 Widget Scale (`#scale-slider`, `50%` to `100%`):** Slider to resize the overall widget.
  - **🔍 Font Size (`14px` to `36px`):** Real-time text font adjustment.
  - **💧 Background Opacity (`25%` to `100%`):** Adjust container transparency while keeping text 100% crisp.
  - **🔊 Volume Slider:** Button toggle with 0% to 100% slider.
  - **⚡ Speed & Voice Profiles:** Speed from `0.5x` to `2.0x`, 4 tonal profiles, and system voice selection.
