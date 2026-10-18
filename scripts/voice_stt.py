#!/usr/bin/env python3
"""
voice_stt.py — Antigravity Speech-to-Text (STT) Bridge & CLI Helper

Soporta:
  1. Captura de micrófono multiplataforma:
     - Linux nativo: arecord / ffmpeg
     - WSL2 / Windows: Captura directa de micrófono Windows vía PowerShell WinMM
     - macOS: rec (sox) / ffmpeg
  2. Motores de transcripción:
     - Google Speech Recognition libre (vía SpeechRecognition, sin clave de API)
     - OpenAI Whisper API (si OPENAI_API_KEY está definida)
     - Whisper local CLI (si whisper está instalado)
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
from pathlib import Path

# Asegurar acceso a paquetes de usuario (~/.local)
for p in Path(os.path.expanduser("~/.local/lib")).glob("python*/site-packages"):
    if str(p) not in sys.path:
        sys.path.append(str(p))

def has_alsa_soundcards() -> bool:
    """Verifica si ALSA tiene dispositivos físicos de captura."""
    if not shutil.which("arecord"):
        return False
    try:
        res = subprocess.run(["arecord", "-l"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return "no soundcards found" not in res.stderr.lower() and res.returncode == 0
    except Exception:
        return False

def get_powershell_executable() -> str:
    """Busca el ejecutable de PowerShell en Windows o WSL2."""
    candidates = [
        "/mnt/c/WINDOWS/System32/WindowsPowerShell/v1.0/powershell.exe",
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
        shutil.which("powershell.exe"),
        shutil.which("powershell")
    ]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    return ""

def record_windows_powershell(duration: int = 5, output_wav: str = None) -> str:
    """Captura audio del micrófono de Windows usando la API nativa WinMM de Windows."""
    ps_exe = get_powershell_executable()
    if not ps_exe:
        return ""

    if not output_wav:
        fd, output_wav = tempfile.mkstemp(suffix=".wav", prefix="antigravity_mic_")
        os.close(fd)

    print(f"[🎙️] Grabando audio con micrófono de Windows durante {duration} segundos... (Habla ahora)", file=sys.stderr)

    ps_code = f"""
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    public class WinMM {{
        [DllImport("winmm.dll", EntryPoint="mciSendStringA", CharSet=CharSet.Ansi)]
        public static extern int mciSendString(string command, string buffer, int bufferSize, IntPtr hwndCallback);
    }}
    "@
    [WinMM]::mciSendString('open new type waveaudio alias recsound', [string]::Empty, 0, [IntPtr]::Zero)
    [WinMM]::mciSendString('record recsound', [string]::Empty, 0, [IntPtr]::Zero)
    Start-Sleep -Seconds {duration}
    $p = [System.IO.Path]::GetTempPath() + 'antigravity_mic_{os.getpid()}.wav'
    [WinMM]::mciSendString('save recsound ' + $p, [string]::Empty, 0, [IntPtr]::Zero)
    [WinMM]::mciSendString('close recsound', [string]::Empty, 0, [IntPtr]::Zero)
    Write-Output $p
    """

    try:
        res = subprocess.run([ps_exe, "-NoProfile", "-Command", ps_code], stdin=subprocess.DEVNULL, capture_output=True)
        out_str = res.stdout.decode("latin1", errors="replace").strip()
        lines = [l.strip() for l in out_str.splitlines() if l.strip()]
        if lines:
            win_path = lines[-1]
            if win_path.startswith("C:") or win_path.startswith("c:"):
                wsl_path = "/mnt/c" + win_path[2:].replace("\\", "/")
                if os.path.exists(wsl_path) and os.path.getsize(wsl_path) > 0:
                    shutil.copyfile(wsl_path, output_wav)
                    try:
                        os.remove(wsl_path)
                    except Exception:
                        pass
                    print(f"[✓] Grabación completada exitosamente: {output_wav}", file=sys.stderr)
                    return output_wav
    except Exception as e:
        print(f"[Error captura Windows] {e}", file=sys.stderr)

    return ""

def record_audio(duration: int = 5, output_wav: str = None) -> str:
    """Graba audio desde el mejor dispositivo disponible en el sistema."""
    system = platform.system().lower()
    is_wsl = "microsoft" in platform.release().lower()

    if not output_wav:
        fd, output_wav = tempfile.mkstemp(suffix=".wav", prefix="antigravity_mic_")
        os.close(fd)

    # 1. En WSL2 o Windows: Si no hay tarjeta en ALSA, usar micrófono de Windows
    if is_wsl or "windows" in system:
        if not has_alsa_soundcards() and get_powershell_executable():
            rec_result = record_windows_powershell(duration=duration, output_wav=output_wav)
            if rec_result:
                return rec_result

    print(f"[🎙️] Grabando audio durante {duration} segundos... (Habla ahora)", file=sys.stderr)

    # 2. Linux nativo con ALSA / ffmpeg
    if "linux" in system:
        if shutil.which("arecord") and has_alsa_soundcards():
            cmd = ["arecord", "-d", str(duration), "-f", "cd", "-t", "wav", output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-y", "-f", "alsa", "-i", "default", "-t", str(duration), output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif get_powershell_executable():
            return record_windows_powershell(duration=duration, output_wav=output_wav)
        else:
            print("[Error] No se encontró dispositivo de grabación accesible.", file=sys.stderr)
            return ""

    # 3. macOS
    elif "darwin" in system:
        if shutil.which("sox"):
            cmd = ["rec", output_wav, "trim", "0", str(duration)]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("ffmpeg"):
            cmd = ["ffmpeg", "-y", "-f", "avfoundation", "-i", ":default", "-t", str(duration), output_wav]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    if os.path.exists(output_wav) and os.path.getsize(output_wav) > 0:
        print(f"[✓] Grabación completada: {output_wav}", file=sys.stderr)
        return output_wav

    return ""

def transcribe_google_free(audio_path: str, language: str = "es") -> str:
    """Transcribe audio usando el motor libre de Google Speech Recognition (sin clave API)."""
    try:
        import speech_recognition as sr
        r = sr.Recognizer()
        lang_code = "es-ES" if language.startswith("es") else language
        with sr.AudioFile(audio_path) as source:
            audio_data = r.record(source)
            text = r.recognize_google(audio_data, language=lang_code)
            return text.strip()
    except Exception as e:
        # Silencioso o informativo
        return ""

def transcribe_whisper_api(audio_path: str, api_key: str = None, language: str = "es") -> str:
    key = api_key or os.environ.get("OPENAI_API_KEY")
    if not key:
        return ""

    boundary = "----WebKitFormBoundaryAntigravitySTT7MA4YWxkTrZu0gW"
    url = "https://api.openai.com/v1/audio/transcriptions"

    with open(audio_path, "rb") as f:
        file_bytes = f.read()

    body = bytearray()
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(f'Content-Disposition: form-data; name="file"; filename="{os.path.basename(audio_path)}"\r\n'.encode("utf-8"))
    body.extend(b"Content-Type: audio/wav\r\n\r\n")
    body.extend(file_bytes)
    body.extend(b"\r\n")

    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(b'Content-Disposition: form-data; name="model"\r\n\r\n')
    body.extend(b"whisper-1\r\n")

    if language:
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(b'Content-Disposition: form-data; name="language"\r\n\r\n')
        body.extend(language.encode("utf-8") + b"\r\n")

    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req = urllib.request.Request(url, data=bytes(body))
    req.add_header("Authorization", f"Bearer {key}")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    try:
        with urllib.request.urlopen(req) as resp:
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
    parser.add_argument("--engine", choices=["auto", "cloud", "google", "local"], default="auto", help="Motor STT a utilizar")
    args = parser.parse_args()

    audio_file = args.file
    if args.record or not audio_file:
        audio_file = record_audio(duration=args.duration)
        if not audio_file:
            print("[Error] No se pudo generar la grabación de audio.", file=sys.stderr)
            sys.exit(1)

    text = ""
    # 1. Cloud Whisper (si está configurada la clave)
    if args.engine in ("auto", "cloud") and os.environ.get("OPENAI_API_KEY"):
        text = transcribe_whisper_api(audio_file, language=args.lang)

    # 2. Google Speech Recognition libre (sin clave, altamente preciso)
    if not text and args.engine in ("auto", "google"):
        text = transcribe_google_free(audio_file, language=args.lang)

    # 3. Whisper local CLI
    if not text and args.engine in ("auto", "local"):
        text = transcribe_local_whisper(audio_file, language=args.lang)

    if text:
        print("\n📝 Transcripción:")
        print(text)
    else:
        print("\n[Aviso] Audio grabado pero no se pudo transcribir.", file=sys.stderr)
        print(f"Ruta: {audio_file}", file=sys.stderr)
        print("Tip: Verifica tu conexión a internet o instala 'whisper' localmente.", file=sys.stderr)

if __name__ == "__main__":
    main()
