#!/usr/bin/env python3
"""
voice_podcast.py — Modo Podcast y Generador de Audio para Antigravity

Convierte explicaciones técnicas, documentos Markdown (README, ROADMAP, guías)
o planes de arquitectura en episodios de audio estructurados para descansar la vista.
"""

import sys
import os
import re
import argparse
import subprocess
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

def clean_markdown_for_speech(md_text: str) -> str:
    """Limpia sintaxis de Markdown para lectura fluida y natural."""
    # Eliminar bloques de código muy largos pero anunciar que hay código
    text = re.sub(r'```[a-zA-Z0-9_]*\n([\s\S]*?)```', r' Bloque de código: \1 ', md_text)
    # Eliminar imágenes
    text = re.sub(r'!\[.*?\]\(.*?\)', '', text)
    # Reemplazar enlaces [texto](url) por 'texto'
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    # Reemplazar negritas y cursivas
    text = re.sub(r'[*_]{1,3}([^*_]+)[*_]{1,3}', r'\1', text)
    # Reemplazar backticks
    text = re.sub(r'`([^`]+)`', r'\1', text)
    # Eliminar líneas divisorias
    text = re.sub(r'^\s*[-*_]{3,}\s*$', '', text, flags=re.MULTILINE)
    # Eliminar múltiples saltos de línea
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

def split_into_chapters(md_text: str):
    """Divide el documento en capítulos por encabezados Markdown (## o #)."""
    lines = md_text.splitlines()
    chapters = []
    current_title = "Introducción"
    current_lines = []

    for line in lines:
        if line.startswith("# ") or line.startswith("## ") or line.startswith("### "):
            if current_lines:
                content = clean_markdown_for_speech("\n".join(current_lines))
                if content:
                    chapters.append((current_title, content))
            current_title = line.lstrip("#").strip()
            current_lines = []
        else:
            current_lines.append(line)

    if current_lines:
        content = clean_markdown_for_speech("\n".join(current_lines))
        if content:
            chapters.append((current_title, content))

    return chapters

def export_podcast(input_file: str, output_path: str, rate: float = 1.0):
    """Genera el audio del podcast a partir de un archivo Markdown."""
    path = Path(input_file)
    if not path.exists():
        print(f"Error: No se encontró el archivo '{input_file}'", file=sys.stderr)
        sys.exit(1)

    raw_text = path.read_text(encoding="utf-8")
    chapters = split_into_chapters(raw_text)

    if not chapters:
        print("El documento está vacío o no contiene contenido narrable.", file=sys.stderr)
        return

    print(f"\n🎙️ Generando Podcast desde: {path.name}")
    print(f"📑 Capítulos detectados: {len(chapters)}")
    for idx, (title, content) in enumerate(chapters, 1):
        words = len(content.split())
        est_min = words / (150 * rate)
        print(f"   Capítulo {idx}: {title} (~{est_min:.1f} min)")

    # Unir capítulos con pausas acústicas claras
    full_narrative = []
    for idx, (title, content) in enumerate(chapters, 1):
        full_narrative.append(f"Capítulo {idx}. {title}.\n\n{content}\n")

    combined_text = "\n\n".join(full_narrative)

    tts_script = BASE_DIR / "scripts" / "voice_tts.py"
    cmd = [
        sys.executable,
        str(tts_script),
        combined_text,
        "--rate", str(rate),
        "--output", output_path
    ]

    print(f"\n⏳ Renderizando audio en: {output_path}...")
    res = subprocess.run(cmd)
    if res.returncode == 0:
        print(f"✔ ¡Podcast generado con éxito en: {output_path}!")
    else:
        print("✖ Error al sintetizar el audio del podcast.", file=sys.stderr)

def main():
    parser = argparse.ArgumentParser(description="Antigravity Podcast Mode & Audio Exporter")
    parser.add_argument("file", help="Ruta al archivo Markdown (.md) a convertir en audio")
    parser.add_argument("-o", "--output", default="podcast_output.wav", help="Archivo de audio de salida (.wav)")
    parser.add_argument("--rate", type=float, default=1.0, help="Velocidad de locución (ej. 1.0, 1.2)")
    parser.add_argument("--list-chapters", action="store_true", help="Solo listar capítulos y duración estimada")
    args = parser.parse_args()

    if args.list_chapters:
        path = Path(args.file)
        if not path.exists():
            print(f"Error: {args.file} no existe", file=sys.stderr)
            sys.exit(1)
        chapters = split_into_chapters(path.read_text(encoding="utf-8"))
        print(f"\n📑 Capítulos en {path.name}:")
        total_words = 0
        for idx, (title, content) in enumerate(chapters, 1):
            w = len(content.split())
            total_words += w
            print(f"   [{idx}] {title} ({w} palabras)")
        print(f"\n⏱ Duración total estimada: ~{total_words / (150 * args.rate):.1f} minutos a {args.rate}x")
        return

    export_podcast(args.file, args.output, rate=args.rate)

if __name__ == "__main__":
    main()
