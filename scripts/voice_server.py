#!/usr/bin/env python3
"""
voice_server.py — Servidor local para Antigravity Voice Assistant

Permite servir el asistente en http://localhost:9000 (origen seguro para Web Speech API en Chrome/Edge).
"""

import http.server
import socketserver
import os
import sys
import json
import urllib.parse
from pathlib import Path

import tempfile
import subprocess

# Asegurar que las dependencias instaladas en ~/.local (pip install --user) estén disponibles
for p in Path(os.path.expanduser("~/.local/lib")).glob("python*/site-packages"):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))

PORT = 9000
BASE_DIR = Path(__file__).resolve().parent.parent

def synthesize_speech(text: str, rate: float = 1.0, voice: str = "es-ES-AlvaroNeural") -> tuple:
    """Retorna (bytes_data, content_type) usando síntesis neuronal de alta fidelidad."""
    import re
    # Limpieza exhaustiva: quitar emojis, tags HTML y markdown residual
    clean_text = re.sub(r"[\U00010000-\U0010ffff]", "", text)
    clean_text = re.sub(r"<[^>]+>", " ", clean_text)
    clean_text = re.sub(r"[*`_~#]", "", clean_text)
    clean_text = re.sub(r"\s+", " ", clean_text).strip()

    if not clean_text:
        return b"", ""

    # Síntesis neuronal de alta fidelidad vía edge-tts (100% gratuita, sin API keys)
    try:
        import asyncio
        import edge_tts
        fd, tmp_file = tempfile.mkstemp(suffix=".mp3", prefix="antigravity_neural_")
        os.close(fd)
        rate_int = int((rate - 1.0) * 100)
        rate_str = f"{rate_int:+d}%"

        target_voice = voice if "-" in voice else "es-ES-AlvaroNeural"

        async def run_edge():
            comm = edge_tts.Communicate(clean_text, target_voice, rate=rate_str)
            await comm.save(tmp_file)

        asyncio.run(run_edge())
        if os.path.exists(tmp_file) and os.path.getsize(tmp_file) > 0:
            with open(tmp_file, "rb") as f:
                data = f.read()
            try:
                os.remove(tmp_file)
            except Exception:
                pass
            return data, "audio/mpeg"
    except Exception as e:
        print(f"[Error Neural TTS] {e}", file=sys.stderr)
    finally:
        if 'tmp_file' in locals() and os.path.exists(tmp_file):
            try:
                os.remove(tmp_file)
            except Exception:
                pass

    return b"", ""

class VoiceRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def end_headers(self):
        # Habilitar CORS y orígenes seguros
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Content-Security-Policy", "frame-ancestors *")
        super().end_headers()

    def do_GET(self):
        clean_path = self.path.split("?")[0]
        if clean_path in ("/", "/audio_assistant.html"):
            file_path = BASE_DIR / "audio_assistant.html"
            if file_path.exists():
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                with open(file_path, "rb") as f:
                    self.wfile.write(f.read())
                return
        elif clean_path == "/api/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "service": "antigravity-voice-assistant"}).encode("utf-8"))
            return
        elif clean_path == "/api/tts":
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            text = params.get("text", [""])[0]
            rate = float(params.get("rate", ["1.0"])[0])
            profile = params.get("profile", ["natural"])[0].lower()
            voice_param = params.get("voice", [""])[0]

            if not text:
                self.send_error(400, "Missing text parameter")
                return

            voice_map = {
                "alvaro": "es-ES-AlvaroNeural",
                "salome": "es-CO-SalomeNeural",
                "jorge": "es-MX-JorgeNeural",
                "paloma": "es-US-PalomaNeural",
                "dalia": "es-MX-DaliaNeural",
                "elvira": "es-ES-ElviraNeural",
                "natural": "es-ES-AlvaroNeural",
                "clear": "es-CO-SalomeNeural",
                "calm": "es-US-PalomaNeural",
                "deep": "es-MX-JorgeNeural"
            }
            target_voice = voice_param if voice_param else voice_map.get(profile, "es-ES-AlvaroNeural")

            data, content_type = synthesize_speech(text=text, rate=rate, voice=target_voice)
            if not data:
                self.send_error(500, "TTS generation failed")
                return

            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        elif clean_path == "/api/dictate":
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)
            duration = int(params.get("duration", ["5"])[0])
            lang = params.get("lang", ["es"])[0]

            try:
                scripts_path = str(Path(__file__).resolve().parent)
                if scripts_path not in sys.path:
                    sys.path.insert(0, scripts_path)
                import voice_stt

                audio_file = voice_stt.record_audio(duration=duration)
                text = ""
                if audio_file and os.path.exists(audio_file):
                    text = voice_stt.transcribe_google_free(audio_file, language=lang)
                    try:
                        os.remove(audio_file)
                    except Exception:
                        pass

                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok", "text": text}).encode("utf-8"))
            except Exception as e:
                self.send_response(500)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode("utf-8"))
            return
        return super().do_GET()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

def run_server():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), VoiceRequestHandler) as httpd:
        print(f"🎙️ Antigravity Voice Server activo en http://localhost:{PORT}")
        print(f"   Sirviendo: {BASE_DIR / 'audio_assistant.html'}")
        print("   Presiona Ctrl+C para detener.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nDeteniendo servidor de voz...")

if __name__ == "__main__":
    run_server()
