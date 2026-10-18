---
name: "bug-hunter"
description: "Root Cause Analysis (RCA), debugging of speech synthesis, audio playback, UI reactivity, and cross-platform TTS engine issues."
---

# Bug Hunter & Debugger Skill — Antigravity Voice Assistant 🎙️

This skill guides Root Cause Analysis (RCA), debugging of audio synthesis anomalies, playback interruption, volume/speed sync, and multi-platform engine fallbacks across Linux, macOS, and Windows.

---

## 📌 Common Anomaly Profiles in Voice Assistant

1. **SpeechSynthesis Silent Failure / Stalling:**
   - Chrome/Electron audio policy pausing long utterances (`window.speechSynthesis` timer bug).
   - Solution: chunking utterances or resetting through `synth.cancel()` before new playback.
2. **Platform Audio Fallback Failure:**
   - Linux: Missing `piper` or `spd-say`/`espeak-ng`.
   - macOS: Invalid voice identifier passed to `say -v`.
   - Windows: PowerShell execution policy blocking `System.Speech`.
3. **High-Contrast & Layout Glitches:**
   - Text overflowing collapsible drawers or scale factor clipping container borders.
   - White text `#ffffff` overridden by inheritance.

---

## 🛠️ Root Cause Analysis (RCA) Protocol

1. **Empirical Evidence (Zero Assumptions):** Inspect browser developer console logs, Web Speech API events (`onerror`, `onend`), and Python CLI exit codes.
2. **Reproduce via Isolation:** Test the offending text string directly in `prepareTextForSpeech()` or `scripts/voice_tts.py`.
3. **Non-Breaking Fixes:** Maintain zero dependencies for default Web Speech API mode and keep graceful degradation for Cloud and Local CLI modes.
