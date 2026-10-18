# User & Usage Guide

This guide describes how to install, configure, and use the **Accessible Voice Assistant** in Antigravity IDE.

---

## 📥 Installation

### 1. Global Plugin Installation (Recommended)

To make the voice assistant automatically available across all your Antigravity workspaces:

```bash
git clone https://github.com/luisfdocelis/antigravity-voice-assistant.git ~/.gemini/config/plugins/accessible-voice-assistant
```

### 2. Workspace-Level Installation

To use it solely in a specific project or workspace:

```bash
cd /path/to/your/project
git clone https://github.com/luisfdocelis/antigravity-voice-assistant.git .gemini/plugins/accessible-voice-assistant
```

---

## 🎛️ Media Player Controls

When the voice assistant widget appears in chat or inside an editor split tab, you have access to transport and configuration controls:

| Control | Description |
| :--- | :--- |
| **`⏮` Prev / Restart** | Jumps to previous section heading or restarts from the beginning. |
| **`▶` Play / `⏸` Pause** | Toggles speech playback without losing your current progress. |
| **`⏭` Next Section** | Jumps directly to the next section heading. |
| **`⏹` Stop** | Halts synthesis, plays subtle stop chime, and resets playback position. |
| **`🔊` Volume Slider** | Expands a quick popover with a `0%` to `100%` volume slider. |
| **`📄 Text ▾`** | Collapses or expands the pure white formatted text viewer. |
| **`📋 Copy`** | Copies the raw formatted Markdown summary directly to your system clipboard. |
| **`⚙️ Settings ▾`** | Toggles accessibility preferences and visual themes drawer. |
| **`⌨️ Shortcuts ▾`** | Displays accessible keyboard hotkeys for hands-free operation. |
| **`🎙️ Dictar`** | Toggles live microphone for voice prompt dictation and voice commands. |

---

## ⌨️ Accessible Keyboard Shortcuts

Operate the voice assistant without leaving your code editor or touching the mouse:

| Shortcut | Action |
| :--- | :--- |
| **`Space`** / **`Ctrl + Alt + Space`** | Play / Pause speech |
| **`Ctrl + Alt + R`** | Restart current section or speech |
| **`Ctrl + Alt + S`** | Stop speech |
| **`Ctrl + Alt + →`** | Skip to next section heading |
| **`Ctrl + Alt + ←`** | Skip to previous section heading |
| **`Ctrl + Alt + ↑`** | Increase speed (`+0.1x`) |
| **`Ctrl + Alt + ↓`** | Decrease speed (`-0.1x`) |
| **`Ctrl + Alt + M`** | Mute / Unmute audio |
| **`Ctrl + Alt + D`** | Toggle microphone for voice dictation & commands |

---

## 🎙️ Hands-Free Voice Commands & Dictation

When the microphone is active (indicated by a pulsating red badge `🔴` and an auditory chime), speak naturally:

### 1. Voice Action Triggers
Execute player and navigation actions hands-free:
- *"Pausar"* / *"Detener"* / *"Para"*: Pauses speech playback.
- *"Continuar"* / *"Reanudar"* / *"Reproducir"*: Resumes speech playback.
- *"Siguiente"* / *"Avanza"*: Jumps to the next section heading.
- *"Anterior"* / *"Regresa"*: Jumps to the previous section heading.
- *"Reiniciar"* / *"Desde el inicio"*: Restarts playback from section 1.
- *"Más rápido"* / *"Acelerar"*: Increases playback rate (`+0.1x`).
- *"Más despacio"* / *"Más lento"*: Decreases playback rate (`-0.1x`).
- *"Silencio"* / *"Mute"*: Toggles audio mute.

### 2. Prompt Dictation
Speak any development question or prompt. It is transcribed in real-time inside the **Dictation drawer** (`dictation-drawer`) and can be copied with one click via **`📋 Copiar Prompt`** into the Antigravity prompt area.

---

## ⚙️ Configuration & Accessibility Settings

Open the **Settings drawer** (`⚙️`) in the player to customize:

### 1. Speech Engine
- **Web Speech API**: Zero configuration required. Uses system voices installed on your OS via the browser/Electron runtime.
- **Local CLI**: Uses the local Python bridge script ([`scripts/voice_tts.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_tts.py)) and local engines (Piper, eSpeak, macOS `say`, Windows SAPI).
- **Cloud Neural**: Supports OpenAI (`tts-1`) and ElevenLabs for natural human voices (enter your API key in the settings input).

### 2. Language Selection
- Choose **Auto-detect** or explicitly select:
  - English (US / UK)
  - Spanish (MX / ES)
  - French
  - German
  - Portuguese
  - Italian
  - Japanese
- Selecting a language filters native system voices to display only compatible voices.

### 3. Visual Themes (16 High-Contrast Palettes)
- **DaisyUI Palettes**: Night, Dracula, Synthwave, Luxury, Forest, Aqua, Cyberpunk, Coffee, Dim, Sunset, Emerald.
- **Developer Palettes**: Nord, Tokyo Night, Monokai, Solarized Dark, Black OLED.

### 4. Text & Widget Scaling
- **Font Size**: Adjustable from `14px` to `36px` in real time.
- **Widget Scale**: Zoom widget from `50%` to `100%` to fit smaller split panes.
- **Background Opacity**: Adjust transparency from `25%` to `100%` while maintaining `100%` opacity on pure white (`#ffffff`) text.
- **Button Display**: Switch between icon-only mode and icon + label mode for high-readability targets.

---

## 🗗 Split-Tab Mode

You can pin the assistant in an editor split pane side-by-side with your code:

1. Ask Antigravity: *"Open voice assistant in an editor tab"*
2. Drag the opened tab to the side split pane or above your integrated terminal.
3. Keep auditory explanations running alongside your active code edits.
