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

PORT = 9000
BASE_DIR = Path(__file__).resolve().parent.parent

class VoiceRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(BASE_DIR), **kwargs)

    def end_headers(self):
        # Habilitar CORS y orígenes seguros
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
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
            if not text:
                self.send_error(400, "Missing text parameter")
                return

            import tempfile
            import subprocess
            fd, tmp_wav = tempfile.mkstemp(suffix=".wav", prefix="antigravity_tts_")
            os.close(fd)
            try:
                speed_val = max(80, min(350, int(160 * rate)))
                cmd = ["espeak-ng", "-v", "es-la", "-s", str(speed_val), "-w", tmp_wav, text]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

                with open(tmp_wav, "rb") as f:
                    wav_data = f.read()

                self.send_response(200)
                self.send_header("Content-Type", "audio/wav")
                self.send_header("Content-Length", str(len(wav_data)))
                self.end_headers()
                self.wfile.write(wav_data)
            except Exception as e:
                self.send_error(500, f"TTS generation error: {e}")
            finally:
                if os.path.exists(tmp_wav):
                    try:
                        os.remove(tmp_wav)
                    except Exception:
                        pass
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
