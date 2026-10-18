# CLI & Developer Reference

This document covers technical details, command-line interfaces, and extensibility points for developers building upon the **Accessible Voice Assistant**.

---

## 🐍 Python CLI Bridge ([`scripts/voice_tts.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_tts.py))

The CLI script provides an OS-agnostic local TTS bridge that can be called from shell scripts, terminal commands, or Antigravity workflows.

### Synopsis

```bash
python3 scripts/voice_tts.py [TEXT] [OPTIONS]
```

Or piped via `stdin`:

```bash
echo "Hello from Antigravity" | python3 scripts/voice_tts.py
```

### Options

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `TEXT` | `string` | `""` | Text to speak. If empty, reads from standard input (`stdin`). |
| `--engine` | `native` \| `cloud` \| `web` | `native` | Text-to-speech engine target. |
| `--voice` | `string` | `""` | Target voice name or identifier (e.g. system voice name on macOS/Windows). |
| `--rate` | `float` | `1.0` | Speech speed multiplier (e.g., `0.8` for slower, `1.2` for faster). |

### System Engine Requirements

#### Linux
The script checks for available engines in order of acoustic quality:
1. **Piper TTS**: Fast local neural TTS (`piper`). Recommended for high-quality offline speech.
2. **Speech Dispatcher**: (`spd-say`)
3. **eSpeak NG**: (`espeak-ng`)
4. **eSpeak**: (`espeak`)

To install standard Linux TTS engines on Debian/Ubuntu:
```bash
sudo apt update && sudo apt install -y speech-dispatcher espeak-ng alsa-utils
```

#### macOS
Uses the built-in native `say` command with word-per-minute rate mapping (`175 * rate`). No extra packages required.

#### Windows
Uses PowerShell and the native .NET assembly `System.Speech.Synthesis.SpeechSynthesizer`. No external dependencies required.

---

## 🎙️ Python STT CLI Bridge ([`scripts/voice_stt.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_stt.py))

Records microphone input and transcribes audio into text from the command line:

```bash
# Record 5 seconds and transcribe:
python3 scripts/voice_stt.py --record --duration 5

# Transcribe an existing WAV file:
python3 scripts/voice_stt.py -f recording.wav --lang es
```

### Options

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `--record` | `flag` | `False` | Captures audio live from the default system microphone. |
| `--duration` | `int` | `5` | Recording duration in seconds. |
| `-f`, `--file` | `string` | `None` | Path to an existing WAV audio file. |
| `--lang` | `string` | `"es"` | Target language code (`es`, `en`, `fr`, etc.). |
---

## 📢 Dev Audio Announcer & Git Diff ([`scripts/voice_notify.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_notify.py))

Executes any terminal build or test command and speaks the outcome, automatically extracting critical exceptions or errors on failure. Also narrates Git diff summaries.

```bash
# Announce test outcome (success or key error traceback):
python3 scripts/voice_notify.py -- pytest
python3 scripts/voice_notify.py -- bash .agents/scripts/verify.sh

# Announce Git diff status before committing:
python3 scripts/voice_notify.py --git-diff
```

### Options

| Flag | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `COMMAND` | `list` | `[]` | The command to run, monitor, and audibly announce. |
| `--git-diff` | `flag` | `False` | Audits modified files, insertions, and deletions in Git and speaks a natural summary. |
| `-m`, `--message` | `string` | `""` | Direct message to announce via speech synthesizer. |
| `--rate` | `float` | `1.0` | Speech playback rate multiplier. |

---

## 🎧 Podcast Mode & Audio Exporter ([`scripts/voice_podcast.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_podcast.py))

Converts Markdown documentation, technical guides, or architecture summaries into structured multi-chapter audio files:

```bash
# List chapters and estimated listening duration:
python3 scripts/voice_podcast.py --list-chapters docs/ROADMAP.md

# Render complete audio podcast to a WAV file:
python3 scripts/voice_podcast.py docs/USER_GUIDE.md -o user_guide_podcast.wav --rate 1.1
```

---

## 🧠 Zero-Config Piper Neural TTS ([`scripts/setup_piper.py`](file:///home/fernando/antigravity-voice-assistant/scripts/setup_piper.py))

Downloads and configures high-quality, lightweight Piper neural TTS voice models offline without paying for cloud APIs:

```bash
# List available and installed models:
python3 scripts/setup_piper.py --list

# Download Spanish neural voice (es_ES-davefx-medium):
python3 scripts/setup_piper.py --install es_ES

# Download Mexican Spanish neural voice (es_MX-ald-medium):
python3 scripts/setup_piper.py --install es_MX
```

---

## 🌐 Local Speech Web Server ([`scripts/voice_server.py`](file:///home/fernando/antigravity-voice-assistant/scripts/voice_server.py))

Starts the lightweight background server providing a secure origin (`http://localhost:54321`) for Web Speech API in Chrome, Edge, and Brave:

```bash
# Start server manually:
python3 scripts/voice_server.py
```

---

## 🤖 MCP Voice Server ([`scripts/mcp_voice_server.py`](file:///home/fernando/antigravity-voice-assistant/scripts/mcp_voice_server.py))

Exposes a JSON-RPC 2.0 stdio server conforming to Model Context Protocol (MCP) to let external agents invoke audio tools:

```bash
# Test MCP tool listing:
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}' | python3 scripts/mcp_voice_server.py
```

---

## 🛠️ Modifying the UI Template

The HTML widget lives at [`skills/accessible-voice-assistant/resources/audio-assistant-template.html`](file:///home/fernando/antigravity-voice-assistant/skills/accessible-voice-assistant/resources/audio-assistant-template.html).

### Structure
- **Theme Definition**: CSS variables applied based on `data-theme` attribute (compatible with DaisyUI).
- **Speech Controller**: JavaScript class orchestrating utterance queuing, rate, pitch, language detection, and audio controls.
- **State Persistence**: Settings are saved to `localStorage.getItem("ava_settings")` to preserve user configuration between assistant sessions.
