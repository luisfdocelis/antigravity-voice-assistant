#!/usr/bin/env python3
"""
setup_piper.py — Instalador y gestor Zero-Config para Piper Neural TTS

Descarga y configura automáticamente modelos neuronales ligeros en español e inglés
para síntesis de voz natural y offline sin costos de API.
"""

import os
import sys
import shutil
import urllib.request
import argparse
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BASE_DIR / "models" / "piper"

# Modelos oficiales ligeros de HuggingFace Piper Voices (ONNX + JSON de configuración)
VOICE_CATALOG = {
    "es_ES": {
        "name": "es_ES-davefx-medium",
        "description": "Español (España) - Voz natural neutra",
        "onnx": "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx",
        "json": "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json",
    },
    "es_MX": {
        "name": "es_MX-ald-medium",
        "description": "Español (México) - Voz clara latinoamericana",
        "onnx": "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_MX/ald/medium/es_MX-ald-medium.onnx",
        "json": "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_MX/ald/medium/es_MX-ald-medium.onnx.json",
    },
    "en_US": {
        "name": "en_US-lessac-medium",
        "description": "English (US) - Natural technical voice",
        "onnx": "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx",
        "json": "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json",
    }
}

def download_file(url: str, dest_path: Path):
    if dest_path.exists() and dest_path.stat().st_size > 0:
        print(f"  ✔ Ya existe: {dest_path.name}")
        return True

    print(f"  ⬇ Descargando {dest_path.name}...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Antigravity-Voice-Assistant/2.5"})
        with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as out_file:
            shutil.copyfileobj(resp, out_file)
        print(f"  ✔ Descargado exitosamente: {dest_path.name}")
        return True
    except Exception as e:
        print(f"  ✖ Error al descargar {url}: {e}", file=sys.stderr)
        if dest_path.exists():
            dest_path.unlink()
        return False

def setup_voice(voice_key: str):
    if voice_key not in VOICE_CATALOG:
        print(f"Error: Voz '{voice_key}' no encontrada en el catálogo. Opciones: {list(VOICE_CATALOG.keys())}")
        return False

    info = VOICE_CATALOG[voice_key]
    MODELS_DIR.mkdir(parents=True, exist_ok=True)

    print(f"\n📦 Configurando modelo: {info['name']} ({info['description']})")
    onnx_dest = MODELS_DIR / f"{info['name']}.onnx"
    json_dest = MODELS_DIR / f"{info['name']}.onnx.json"

    ok_onnx = download_file(info["onnx"], onnx_dest)
    ok_json = download_file(info["json"], json_dest)

    if ok_onnx and ok_json:
        print(f"✔ Modelo listo en: {onnx_dest}")
        return True
    return False

def list_installed_voices():
    print(f"\n📁 Modelos instalados en: {MODELS_DIR}")
    if not MODELS_DIR.exists():
        print("  (Ningún modelo descargado aún)")
        return []

    installed = []
    for onnx in MODELS_DIR.glob("*.onnx"):
        json_file = onnx.with_suffix(".onnx.json")
        has_json = json_file.exists()
        size_mb = onnx.stat().st_size / (1024 * 1024)
        print(f"  • {onnx.name} ({size_mb:.1f} MB) - Config: {'OK' if has_json else 'Falta .json'}")
        installed.append(onnx.stem)
    return installed

def check_piper_binary():
    piper_path = shutil.which("piper")
    if piper_path:
        print(f"✔ Binario de Piper encontrado en el sistema: {piper_path}")
        return piper_path
    else:
        print("ℹ️ Binario 'piper' no encontrado en el PATH del sistema.")
        print("  Tip para instalar piper:")
        print("  - Python: pip install piper-tts")
        print("  - Linux x86_64 release: https://github.com/rhasspy/piper/releases")
        return None

def main():
    parser = argparse.ArgumentParser(description="Zero-Config Piper Neural TTS Model Manager")
    parser.add_argument("--install", choices=list(VOICE_CATALOG.keys()) + ["all"], default=None,
                        help="Descargar e instalar voz neural específica o todas")
    parser.add_argument("--list", action="store_true", help="Listar voces disponibles e instaladas")
    parser.add_argument("--check", action="store_true", help="Verificar estado de Piper y modelos")
    args = parser.parse_args()

    if args.list:
        print("🎙️ Catálogo de Voces Neurales Piper:")
        for k, v in VOICE_CATALOG.items():
            print(f"  [{k}] {v['name']} — {v['description']}")
        list_installed_voices()
        return

    if args.check:
        check_piper_binary()
        list_installed_voices()
        return

    if args.install:
        if args.install == "all":
            for k in VOICE_CATALOG:
                setup_voice(k)
        else:
            setup_voice(args.install)
        return

    # Si se ejecuta sin argumentos, mostrar ayuda o estado
    check_piper_binary()
    list_installed_voices()
    print("\n💡 Usa '--install es_ES' para descargar el modelo neuronal en español.")

if __name__ == "__main__":
    main()
