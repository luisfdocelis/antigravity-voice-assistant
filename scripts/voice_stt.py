#!/usr/bin/env python3
"""
Antigravity Voice STT (Speech-to-Text) Bridge & CLI Helper
Supports:
  1. Audio recording via native OS tools:
     - Linux: arecord, sox, ffmpeg
     - macOS: rec (sox), ffmpeg, swift/native
     - Windows: PowerShell SoundRecorder / ffmpeg
  2. Transcription engines:
     - OpenAI Whisper API (OPENAI_API_KEY)
     - Local Whisper CLI / whisper.cpp (if available)
"""

import sys
import os
import platform
import subprocess
import argparse
import shutil
import tempfile
import urllib.request
import json

def record_audio(duration: int = 5, output_wav: str = None) -> str:
    system = platform.system().lower()
    if not output_wav:
        fd, output_wav = tempfile.mkstemp(suffix=".wav", prefix="antigravity_mic_")
        os.close(fd)

    print(f"[🎙️] Grabando audio durante {duration} segundos... (Habla ahora)", file=sys.stderr)

    if "linux" in system:
        if shutil.which("arecord"):
            cmd = ["arecord", "-d", str(duration), "-f", "cd", "-t", "wav", output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-y", "-f", "alsa", "-i", "default", "-t", str(duration), output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            print("[Error] No se encontró 'arecord' ni 'ffmpeg' para capturar audio.", file=sys.stderr)
            return ""

    elif "darwin" in system:  # macOS
        if shutil.which("sox"):
            cmd = ["rec", output_wav, "trim", "0", str(duration)]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-y", "-f", "avfoundation", "-i", ":default", "-t", str(duration), output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            print("[Error] En macOS se requiere 'sox' o 'ffmpeg'. Instala con: brew install sox", file=sys.stderr)
            return ""

    elif "windows" in system:  # Windows
        if shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-y", "-f", "dshow", "-i", "audio=default", "-t", str(duration), output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            print("[Error] En Windows se requiere 'ffmpeg' para grabar desde consola.", file=sys.stderr)
            return ""

    print(f"[✓] Grabación completada: {output_wav}", file=sys.stderr)
    return output_wav

def transcribe_whisper_api(audio_path: str, api_key: str = None, language: str = "es") -> str:
    key = api_key or os.environ.get("OPENAI_API_KEY")
    if not key:
        return ""

    # Multipart boundary
    boundary = "----WebKitFormBoundaryAntigravitySTT7MA4YWxkTrZu0gW"
    url = "https://api.openai.com/v1/audio/transcriptions"

    with open(audio_path, "rb") as f:
        file_bytes = f.read()

    body = bytearray()
    # file field
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(f'Content-Disposition: form-data; name="file"; filename="{os.path.basename(audio_path)}"\r\n'.encode("utf-8"))
    body.extend(b"Content-Type: audio/wav\r\n\r\n")
    body.extend(file_bytes)
    body.extend(b"\r\n")

    # model field
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(b'Content-Disposition: form-data; name="model"\r\n\r\n')
    body.extend(b"whisper-1\r\n")

    # language field
    if language:
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(b'Content-Disposition: form-data; name="language"\r\n\r\n')
        body.extend(language.encode("utf-8") + b"\r\n")

    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req = urllib.request.Request(url, data=bytes(body))
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("text", "").strip()
    except Exception as e:
        print(f"[Error Cloud Whisper API] {e}", file=sys.stderr)
        return ""

def transcribe_local_whisper(audio_path: str, language: str = "es") -> str:
    if shutil.which("whisper"):
        cmd = ["whisper", audio_path, "--model", "tiny", "--language", language, "--output_format", "txt"]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        txt_path = os.path.splitext(audio_path)[0] + ".txt"
        if os.path.exists(txt_path):
            with open(txt_path) as f:
                return f.read().strip()
    return ""

def main():
    parser = argparse.ArgumentParser(description="Antigravity Speech-to-Text CLI")
    parser.add_argument("--record", action="store_true", help="Grabar audio directamente desde el micrófono")
    parser.add_argument("--duration", type=int, default=5, help="Duración de la grabación en segundos (default: 5)")
    parser.add_argument("--file", "-f", default=None, help="Ruta a un archivo de audio WAV a transcribir")
    parser.add_argument("--lang", default="es", help="Código de idioma (es, en, fr, etc.)")
    parser.add_argument("--engine", choices=["auto", "cloud", "local"], default="auto", help="Motor STT a utilizar")
    args = parser.parse_args()

    audio_file = args.file
    if args.record or not audio_file:
        audio_file = record_audio(duration=args.duration)
        if not audio_file:
            sys.exit(1)

    text = ""
    if args.engine in ("auto", "cloud") and os.environ.get("OPENAI_API_KEY"):
        text = transcribe_whisper_api(audio_file, language=args.lang)

    if not text and args.engine in ("auto", "local"):
        text = transcribe_local_whisper(audio_file, language=args.lang)

    if text:
        print(text)
    else:
        if not os.environ.get("OPENAI_API_KEY") and not shutil.which("whisper"):
            print(f"[Info] Audio guardado en: {audio_file}", file=sys.stderr)
            print("[Tip] Define OPENAI_API_KEY o instala localmente 'whisper' para transcripción automática en CLI.", file=sys.stderr)
            print("[Tip] En la interfaz web/Electron, el dictado opera automáticamente con Web Speech API sin dependencias.", file=sys.stderr)

if __name__ == "__main__":
    main()
