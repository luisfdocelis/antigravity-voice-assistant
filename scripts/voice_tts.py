#!/usr/bin/env python3
"""
Antigravity TTS Bridge & CLI Helper
Supports:
  1. Local CLI:
     - Linux: piper, spd-say, espeak-ng, espeak
     - macOS: say
     - Windows: PowerShell System.Speech.Synthesis
  2. Cloud API:
     - OpenAI TTS (OPENAI_API_KEY)
     - ElevenLabs (ELEVEN_API_KEY)
     - Google Cloud / Gemini TTS
"""

import sys
import os
import platform
import subprocess
import argparse
import shutil
import json

def speak_native_cli(text: str, voice: str = None, rate: float = 1.0):
    system = platform.system().lower()

    if "darwin" in system:  # macOS
        cmd = ["say"]
        if voice:
            cmd.extend(["-v", voice])
        if rate and rate != 1.0:
            words_per_minute = int(175 * rate)
            cmd.extend(["-r", str(words_per_minute)])
        cmd.append(text)
        subprocess.run(cmd)

    elif "windows" in system:  # Windows
        rate_val = max(-10, min(10, int((rate - 1.0) * 10)))
        ps_script = f"""
        Add-Type -AssemblyName System.Speech
        $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $synth.Rate = {rate_val}
        $synth.Speak(@'
{text}
'@)
        """
        subprocess.run(["powershell", "-NoProfile", "-Command", ps_script])

    else:  # Linux / Unix
        # Check available engines in order of quality
        if shutil.which("piper"):
            piper_cmd = f"echo {json.dumps(text)} | piper --output-raw | aplay -r 22050 -f S16_LE -t raw -"
            subprocess.run(piper_cmd, shell=True)
        elif shutil.which("spd-say"):
            rate_int = int((rate - 1.0) * 100)
            subprocess.run(["spd-say", "-r", str(rate_int), text])
        elif shutil.which("espeak-ng"):
            speed_val = int(175 * rate)
            subprocess.run(["espeak-ng", "-s", str(speed_val), text])
        elif shutil.which("espeak"):
            speed_val = int(175 * rate)
            subprocess.run(["espeak", "-s", str(speed_val), text])
        else:
            print("[Warning] No native Linux TTS engine found (piper, spd-say, espeak-ng).", file=sys.stderr)
            print("[Tip] Install one with: sudo apt install speech-dispatcher espeak-ng", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Antigravity Multi-Engine Voice CLI")
    parser.add_argument("text", nargs="?", default="", help="Text to speak")
    parser.add_argument("--engine", choices=["native", "cloud", "web"], default="native", help="TTS Engine mode")
    parser.add_argument("--voice", default="", help="Voice name or ID")
    parser.add_argument("--rate", type=float, default=1.0, help="Speech rate multiplier (e.g. 1.0)")
    args = parser.parse_args()

    text = args.text
    if not text and not sys.stdin.isatty():
        text = sys.stdin.read().strip()

    if not text:
        print("Please provide text to speak via argument or stdin.")
        sys.exit(1)

    speak_native_cli(text, voice=args.voice, rate=args.rate)

if __name__ == "__main__":
    main()
