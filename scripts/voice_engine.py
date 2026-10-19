#!/usr/bin/env python3
"""
voice_engine.py — Motor de Voz Ligero para Antigravity IDE
===========================================================
Proporciona:
  1. Dictado por micrófono para escribir y refinar prompts en el chat (--dictate)
  2. Síntesis neuronal de alta fidelidad para leer respuestas (--speak)
  
100% Gratuito, sin OpenAI ni API keys requeridas.
"""

import sys
import os
import json
import argparse
import tempfile
import subprocess
import asyncio
import re
from pathlib import Path

# Descubrimiento automático de paquetes locales en ~/.local
for p in Path(os.path.expanduser("~/.local/lib")).glob("python*/site-packages"):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

def get_pulse_env():
    """Configura el entorno de audio para WSLg / Linux nativo."""
    env = os.environ.copy()
    wslg_pulse = "/mnt/wslg/PulseServer"
    if os.path.exists(wslg_pulse) and "PULSE_SERVER" not in env:
        env["PULSE_SERVER"] = wslg_pulse
    return env

def dictate(duration: int = 5, language: str = "es-ES") -> dict:
    """Graba audio del micrófono y retorna el texto transcrito."""
    try:
        import speech_recognition as sr
    except ImportError:
        return {"success": False, "error": "Falta speech_recognition. Ejecuta pip install SpeechRecognition"}

    env = get_pulse_env()
    fd, tmp_wav = tempfile.mkstemp(suffix=".wav", prefix="antigravity_dictate_")
    os.close(fd)

    recorded = False
    # 1. Intentar grabar con parecord (PulseAudio/WSLg directo a Windows)
    if subprocess.run(["which", "parecord"], stdout=subprocess.DEVNULL).returncode == 0:
        try:
            # Grabar durante `duration` segundos
            subprocess.run(["parecord", tmp_wav], env=env, timeout=duration, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.TimeoutExpired:
            recorded = True
        except Exception:
            pass

    # 2. Fallback: intentar arecord estándar
    if not recorded or not os.path.exists(tmp_wav) or os.path.getsize(tmp_wav) < 1000:
        if subprocess.run(["which", "arecord"], stdout=subprocess.DEVNULL).returncode == 0:
            try:
                subprocess.run(["arecord", "-d", str(duration), "-f", "cd", "-t", "wav", tmp_wav], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                recorded = True
            except Exception:
                pass

    if not os.path.exists(tmp_wav) or os.path.getsize(tmp_wav) < 1000:
        try:
            os.remove(tmp_wav)
        except Exception:
            pass
        return {"success": False, "error": "No se detectó audio en el micrófono o se agotó el tiempo."}

    # Transcripción con Google Speech Recognition (gratuito, alta precisión en español)
    try:
        r = sr.Recognizer()
        with sr.AudioFile(tmp_wav) as source:
            audio = r.record(source)
        text = r.recognize_google(audio, language=language)
        return {"success": True, "text": text.strip()}
    except sr.UnknownValueError:
        return {"success": False, "error": "No se entendió el audio. Por favor intenta hablar más cerca del micrófono."}
    except sr.RequestError as e:
        return {"success": False, "error": f"Error de conexión con el servicio de reconocimiento: {e}"}
    except Exception as e:
        return {"success": False, "error": str(e)}
    finally:
        if os.path.exists(tmp_wav):
            try:
                os.remove(tmp_wav)
            except Exception:
                pass

def clean_speech_text(text: str) -> str:
    """Limpia markdown, etiquetas HTML y caracteres especiales para lectura fluida."""
    # Eliminar bloques de código grandes para evitar lecturas tediosas
    text = re.sub(r"```[\s\S]*?```", " [Bloque de código omitido] ", text)
    # Quitar emojis
    text = re.sub(r"[\U00010000-\U0010ffff]", "", text)
    # Quitar tags HTML
    text = re.sub(r"<[^>]+>", " ", text)
    # Quitar formato markdown
    text = re.sub(r"[*`_~#]", "", text)
    # Normalizar espacios
    text = re.sub(r"\s+", " ", text).strip()
    return text

def speak(text: str, voice: str = "es-ES-AlvaroNeural", rate: float = 1.0, output_file: str = None) -> dict:
    """Genera audio neural de alta fidelidad para el texto dado."""
    try:
        import edge_tts
    except ImportError:
        return {"success": False, "error": "Falta edge-tts. Ejecuta pip install edge-tts"}

    clean_text = clean_speech_text(text)
    if not clean_text:
        return {"success": False, "error": "Texto vacío"}

    rate_int = int((rate - 1.0) * 100)
    rate_str = f"{rate_int:+d}%"

    target_file = output_file
    is_temp = False
    if not target_file:
        fd, target_file = tempfile.mkstemp(suffix=".mp3", prefix="antigravity_speech_")
        os.close(fd)
        is_temp = True

    try:
        async def run_synth():
            comm = edge_tts.Communicate(clean_text[:4000], voice, rate=rate_str)
            await comm.save(target_file)

        asyncio.run(run_synth())

        if not os.path.exists(target_file) or os.path.getsize(target_file) == 0:
            return {"success": False, "error": "No se pudo sintetizar el audio"}

        return {"success": True, "file": target_file, "size": os.path.getsize(target_file)}
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    parser = argparse.ArgumentParser(description="Antigravity Voice Engine CLI")
    parser.add_argument("--dictate", action="store_true", help="Grabar micrófono y transcribir texto")
    parser.add_argument("--duration", type=int, default=5, help="Duración de la grabación en segundos (default 5)")
    parser.add_argument("--lang", default="es-ES", help="Idioma de reconocimiento (default es-ES)")
    parser.add_argument("--speak", type=str, default="", help="Texto a sintetizar en voz neural")
    parser.add_argument("--voice", default="es-ES-AlvaroNeural", help="Voz neural a utilizar")
    parser.add_argument("--rate", type=float, default=1.0, help="Velocidad de reproducción (default 1.0)")
    parser.add_argument("--output", type=str, default=None, help="Archivo MP3 de salida para la síntesis")

    args = parser.parse_args()

    if args.dictate:
        result = dictate(duration=args.duration, language=args.lang)
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(0 if result.get("success") else 1)

    if args.speak:
        result = speak(args.speak, voice=args.voice, rate=args.rate, output_file=args.output)
        print(json.dumps(result, ensure_ascii=False))
        sys.exit(0 if result.get("success") else 1)

    parser.print_help()
    sys.exit(1)

if __name__ == "__main__":
    main()
