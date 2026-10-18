#!/usr/bin/env python3
"""
mcp_voice_server.py — Servidor MCP (Model Context Protocol) para Antigravity Voice Assistant

Permite a agentes y herramientas en Antigravity interactuar mediante JSON-RPC stdio
para síntesis de voz, narración de errores, exportación de audio y verificación de estado.
"""

import sys
import json
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

TOOLS = [
    {
        "name": "speak_text",
        "description": "Sintetiza texto en voz alta utilizando el motor de audio local o configurado.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "text": {"type": "string", "description": "Texto a narrar"},
                "rate": {"type": "number", "description": "Velocidad de locución (ej. 1.0, 1.2)", "default": 1.0}
            },
            "required": ["text"]
        }
    },
    {
        "name": "narrate_error",
        "description": "Extrae el error principal de una traza de fallo y lo anuncia verbalmente.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "traceback": {"type": "string", "description": "Texto del traceback o error de consola"}
            },
            "required": ["traceback"]
        }
    },
    {
        "name": "export_podcast",
        "description": "Convierte un archivo Markdown en un podcast de audio estructurado por capítulos.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "file_path": {"type": "string", "description": "Ruta al archivo Markdown (.md)"},
                "output_path": {"type": "string", "description": "Ruta al archivo .wav de salida", "default": "podcast.wav"}
            },
            "required": ["file_path"]
        }
    },
    {
        "name": "get_status",
        "description": "Reporta el estado del asistente de voz, el servidor local de localhost:9000 y los motores TTS disponibles.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    }
]

def handle_speak_text(args):
    text = args.get("text", "")
    rate = args.get("rate", 1.0)
    tts_script = BASE_DIR / "scripts" / "voice_tts.py"
    res = subprocess.run([sys.executable, str(tts_script), text, "--rate", str(rate)], capture_output=True, text=True)
    return {"success": res.returncode == 0, "output": res.stdout or res.stderr}

def handle_narrate_error(args):
    tb = args.get("traceback", "")
    notify_script = BASE_DIR / "scripts" / "voice_notify.py"
    # Pasar el traceback simulando un comando que falló
    res = subprocess.run([sys.executable, str(notify_script), "python3", "-c", f"raise Exception({json.dumps(tb)})"], capture_output=True, text=True)
    return {"success": True, "output": res.stdout or res.stderr}

def handle_export_podcast(args):
    file_path = args.get("file_path", "")
    output_path = args.get("output_path", "podcast.wav")
    podcast_script = BASE_DIR / "scripts" / "voice_podcast.py"
    res = subprocess.run([sys.executable, str(podcast_script), file_path, "-o", output_path], capture_output=True, text=True)
    return {"success": res.returncode == 0, "output": res.stdout or res.stderr}

def handle_get_status(_):
    import shutil
    piper = shutil.which("piper") is not None
    espeak = shutil.which("espeak-ng") is not None or shutil.which("espeak") is not None
    spdsay = shutil.which("spd-say") is not None

    return {
        "status": "ready",
        "version": "3.0.0",
        "engines": {
            "piper_neural": piper,
            "espeak_ng": espeak,
            "speech_dispatcher": spdsay
        },
        "server_url": "http://localhost:9000"
    }

def process_request(req):
    req_id = req.get("id")
    method = req.get("method")
    params = req.get("params", {})

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {"tools": TOOLS}
        }
    elif method == "tools/call":
        tool_name = params.get("name")
        tool_args = params.get("arguments", {})

        if tool_name == "speak_text":
            result = handle_speak_text(tool_args)
        elif tool_name == "narrate_error":
            result = handle_narrate_error(tool_args)
        elif tool_name == "export_podcast":
            result = handle_export_podcast(tool_args)
        elif tool_name == "get_status":
            result = handle_get_status(tool_args)
        else:
            return {
                "jsonrpc": "2.0",
                "id": req_id,
                "error": {"code": -32601, "message": f"Herramienta desconocida: {tool_name}"}
            }

        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "content": [{"type": "text", "text": json.dumps(result, indent=2)}]
            }
        }
    elif method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "antigravity-voice-mcp", "version": "3.0.0"}
            }
        }
    else:
        return {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"code": -32601, "message": f"Método no soportado: {method}"}
        }

def main():
    # Procesar peticiones JSON-RPC sobre stdio
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            res = process_request(req)
            sys.stdout.write(json.dumps(res) + "\n")
            sys.stdout.flush()
        except Exception as e:
            err_res = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {"code": -32700, "message": f"Parse error: {e}"}
            }
            sys.stdout.write(json.dumps(err_res) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
