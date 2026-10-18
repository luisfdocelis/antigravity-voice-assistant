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
