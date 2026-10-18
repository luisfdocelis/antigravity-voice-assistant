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

## 🛠️ Modifying the UI Template

The HTML widget lives at [`skills/accessible-voice-assistant/resources/audio-assistant-template.html`](file:///home/fernando/antigravity-voice-assistant/skills/accessible-voice-assistant/resources/audio-assistant-template.html).

### Structure
- **Theme Definition**: CSS variables applied based on `data-theme` attribute (compatible with DaisyUI).
- **Speech Controller**: JavaScript class orchestrating utterance queuing, rate, pitch, language detection, and audio controls.
- **State Persistence**: Settings are saved to `localStorage.getItem("ava_settings")` to preserve user configuration between assistant sessions.
