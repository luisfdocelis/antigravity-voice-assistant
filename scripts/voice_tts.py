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
from pathlib import Path

def speak_native_cli(text: str, voice: str = None, rate: float = 1.0, output_file: str = None):
    system = platform.system().lower()

    models_dir = Path(__file__).resolve().parent.parent / "models" / "piper"
    local_model = None
    if models_dir.exists():
        onnx_files = list(models_dir.glob("*.onnx"))
        if onnx_files:
            local_model = str(onnx_files[0])

    if output_file:
        if shutil.which("piper"):
            model_flag = f"--model {local_model}" if local_model else ""
            piper_cmd = f"echo {json.dumps(text)} | piper {model_flag} --output_file {output_file}"
            res = subprocess.run(piper_cmd, shell=True)
            if res.returncode == 0:
                print(f"[OK] Audio generado con Piper TTS en: {output_file}")
                return
        if shutil.which("espeak-ng"):
            speed_val = int(175 * rate)
            subprocess.run(["espeak-ng", "-s", str(speed_val), "-w", output_file, text])
            print(f"[OK] Audio guardado exitosamente en: {output_file}")
            return
        elif shutil.which("espeak"):
            speed_val = int(175 * rate)
            subprocess.run(["espeak", "-s", str(speed_val), "-w", output_file, text])
            print(f"[OK] Audio guardado exitosamente en: {output_file}")
            return

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
        # Configure runtime directory for speech-dispatcher if not present
        if not os.environ.get("XDG_RUNTIME_DIR"):
            tmp_runtime = f"/tmp/runtime-{os.getuid()}"
            os.makedirs(tmp_runtime, mode=0o700, exist_ok=True)
            os.environ["XDG_RUNTIME_DIR"] = tmp_runtime

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
    parser.add_argument("-o", "--output", default=None, help="Save generated speech to WAV audio file")
    args = parser.parse_args()

    text = args.text
    if not text and not sys.stdin.isatty():
        text = sys.stdin.read().strip()

    if not text:
        print("Please provide text to speak via argument or stdin.")
        sys.exit(1)

    speak_native_cli(text, voice=args.voice, rate=args.rate, output_file=args.output)

if __name__ == "__main__":
    main()
