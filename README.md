# 🦅 Accessible Voice Assistant for Antigravity

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Theme: Dark High Contrast](https://img.shields.io/badge/Theme-Dark%20High%20Contrast-yellow.svg)](#)
[![Accessibility: Low Vision](https://img.shields.io/badge/Accessibility-Low%20Vision-emerald.svg)](#)
[![Multilingual: EN/ES/FR/DE/PT/IT/JA](https://img.shields.io/badge/Multilingual-EN%20%7C%20ES%20%7C%20FR%20%7C%20DE%20%7C%20PT-blueviolet.svg)](#)

An accessible plugin and skill for **Antigravity IDE** designed for users with **low vision** and **dark theme** preferences.

Provides an elegant, compact media-player-style voice assistant with multilingual speech synthesis (automatic language detection + manual selector for English, Spanish, French, German, Portuguese, Italian, Japanese), structured speech cadence (sections, options, steps, links), 16 high-contrast themes, volume slider popover, variable speed, pure white typography, and split-editor tab support.

---

## ✨ Features

- ⚙️ **Triple Speech Engine Architecture (User Selectable)**:
  1. **Web Speech API**: Zero-configuration native speech engine via browser/Electron on Linux, macOS, and Windows.
  2. **Local CLI Engine**: Cross-platform script ([`scripts/voice_tts.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_tts.py)) running local neural models like Piper TTS/eSpeak-ng (Linux), `say` (macOS), or SAPI (Windows).
  3. **Cloud Neural Engine**: Ultra-realistic voices using OpenAI TTS (`tts-1`) or ElevenLabs by providing an optional API key in Settings.
- 🌐 **Multilingual Speech Synthesis & Auto-Detection**: Automatically detects the response language or allows choosing English (US/UK), Spanish (MX/ES), French, German, Portuguese, Italian, or Japanese.
- 🎙️ **Structured Audio Cadence**: Speaks headings, bullets, numbered steps, and markdown links with natural pacing and language-appropriate cues.
- 🎛️ **Compact Media Player**: Modern transport controls (`⏮` Restart, `▶`/`⏸` Play/Pause, `⏹` Stop, `⏻` Power).
- 🔊 **Quick Volume Toggle**: Speaker icon that reveals a full 0% to 100% volume slider.
- 🎨 **16 High-Contrast Themes**: 11 DaisyUI palettes (Night, Dracula, Synthwave, Luxury, Forest, Aqua, Cyberpunk, Coffee, Dim, Sunset, Emerald) + 5 developer favorites (Nord, Tokyo Night, Monokai, Solarized Dark, Black OLED).
- ⚡ **Adjustable Speed**: Precise rate control from `0.5x` to `2.0x` in steps of `0.1x`.
- 🔍 **Dynamic Text Scaling**: Font size slider (`14px` to `36px`) and widget scale adjustment (`50%` to `100%`).
- 💧 **Background Opacity**: Control container transparency (`25%` to `100%`) while keeping pure white text (`#ffffff`) 100% crisp.
- 📋 **One-Click Markdown Copy**: Instantly copy formatted text to the clipboard.
- 🗗 **Split Tab / Panel Mode**: Pin the assistant in an editor split pane side-by-side with code or above the terminal.

---

## 🚀 Installation in Antigravity

### Global Installation (Recommended)

Clone this repository into your Antigravity plugins directory:

```bash
git clone https://github.com/luisfdocelis/antigravity-voice-assistant.git ~/.gemini/config/plugins/accessible-voice-assistant
```

Antigravity will automatically detect the plugin across all your workspaces and projects.

---

## 📚 Documentation

For complete technical and user documentation, see:

- 📖 [**User & Usage Guide**](docs/USER_GUIDE.md): Installation, media player controls, accessibility options, and split-tab setup.
- 🏗️ [**Architecture & Design**](docs/ARCHITECTURE.md): Multi-engine overview, cadence formatting rules, and component breakdown.
- 💻 [**CLI & Developer Reference**](docs/CLI_REFERENCE.md): Standalone CLI bridge usage, supported OS engines, and widget extension tips.
- 🗺️ [**Product Roadmap**](docs/ROADMAP.md): Evolution plan, upcoming features (v1.2, v2.0, v3.0), and accessibility milestones.

---

## 📄 License

Distributed under the **MIT** license. See [LICENSE](LICENSE) for details.
