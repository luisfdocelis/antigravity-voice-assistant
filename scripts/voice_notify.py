#!/usr/bin/env python3
"""
Antigravity Voice Notify & Dev Audio Announcer
Provides:
  1. Terminal & Test Announcer:
     Executes a build or test command, captures exit status, parses tracebacks/errors,
     and announces results audibly.
  2. Git Audio Diff Reader:
     Analyzes staged and unstaged git changes and narrates an auditory summary of diffs.
"""

import sys
import os
import subprocess
import argparse
import time
import re
from typing import Tuple, List

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TTS_SCRIPT = os.path.join(SCRIPT_DIR, "voice_tts.py")

def speak(text: str, rate: float = 1.0, lang: str = "es"):
    """Invokes local voice_tts.py script to speak the announcement."""
    if not text:
        return
    print(f"\n[📢 Audio Announcer] {text}", file=sys.stderr)
    try:
        cmd = [sys.executable, TTS_SCRIPT, text, "--rate", str(rate)]
        subprocess.run(cmd)
    except Exception as e:
        print(f"[Warning] Failed to speak: {e}", file=sys.stderr)

def extract_key_error(output: str) -> str:
    """Extracts the most informative single-line error message from command output."""
    if not output:
        return "Error no identificado en la salida."

    lines = [l.strip() for l in output.strip().split("\n") if l.strip()]

    # Priority patterns: Python exceptions, AssertionErrors, SyntaxErrors, npm/build errors
    error_patterns = [
        re.compile(r"^[A-Za-z0-9_]+Error:\s*(.+)$"),
        re.compile(r"^AssertionError:\s*(.+)$"),
        re.compile(r"^FAILED\s+(.+)$"),
        re.compile(r"error:\s*(.+)$", re.IGNORECASE),
        re.compile(r"^fatal:\s*(.+)$", re.IGNORECASE),
    ]

    for line in reversed(lines):
        for pat in error_patterns:
            m = pat.search(line)
            if m:
                # Clean up punctuation and return
                return line

    # Fallback to the last non-empty line
    return lines[-1] if lines else "Error durante la ejecución."

def run_and_announce_command(cmd_args: List[str], lang: str = "es") -> int:
    """Executes a command and announces success or error with key traceback info."""
    start_time = time.time()
    cmd_name = os.path.basename(cmd_args[0])
    print(f"[🚀 Running Command] {' '.join(cmd_args)}", file=sys.stderr)

    proc = subprocess.Popen(
        cmd_args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    stdout, stderr = proc.communicate()
    duration = time.time() - start_time
    dur_str = f"{duration:.1f} segundos"

    # Forward stdout & stderr to terminal
    if stdout:
        sys.stdout.write(stdout)
    if stderr:
        sys.stderr.write(stderr)

    if proc.returncode == 0:
        msg = f"El comando {cmd_name} terminó exitosamente en {dur_str}."
        speak(msg, rate=1.05, lang=lang)
    else:
        combined_output = (stderr or stdout or "").strip()
        key_error = extract_key_error(combined_output)
        # Clean special chars from error for smooth speech
        clean_error = key_error.replace("`", "").replace("'", "").replace('"', "")
        msg = f"El comando {cmd_name} falló tras {dur_str}. {clean_error}"
        speak(msg, rate=1.0, lang=lang)

    return proc.returncode

def get_git_diff_summary(lang: str = "es") -> str:
    """Analyzes git status and git diff to produce a spoken auditory summary."""
    try:
        # Check if in a git repo
        subprocess.run(["git", "rev-parse", "--is-inside-work-tree"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except Exception:
        return "No te encuentras dentro de un repositorio Git."

    # Status summary
    status_proc = subprocess.run(["git", "status", "--porcelain"],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    status_lines = [l for l in status_proc.stdout.split("\n") if l.strip()]

    if not status_lines:
        return "El árbol de trabajo está completamente limpio. No hay cambios pendientes."

    total_files = len(status_lines)
    modified = sum(1 for l in status_lines if l.startswith(" M") or l.startswith("M "))
    untracked = sum(1 for l in status_lines if l.startswith("??"))
    added = sum(1 for l in status_lines if l.startswith("A ") or l.startswith("AM"))

    # Diff stat
    diff_proc = subprocess.run(["git", "diff", "--stat", "HEAD"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    diff_output = diff_proc.stdout.strip()

    ins_count = 0
    del_count = 0
    stat_match = re.search(r"(\d+)\s+insertion", diff_output)
    if stat_match:
        ins_count = int(stat_match.group(1))
    stat_del = re.search(r"(\d+)\s+deletion", diff_output)
    if stat_del:
        del_count = int(stat_del.group(1))

    # Top modified files
    top_files = []
    for l in status_lines[:3]:
        parts = l.strip().split()
        if len(parts) >= 2:
            top_files.append(os.path.basename(parts[-1]))

    files_list_str = ", ".join(top_files) if top_files else "varios archivos"

    summary = f"Resumen de Git: {total_files} archivos con cambios. "
    if modified:
        summary += f"{modified} modificados. "
    if untracked:
        summary += f"{untracked} nuevos sin seguimiento. "
    if ins_count or del_count:
        summary += f"Se agregaron {ins_count} líneas y se eliminaron {del_count}. "

    summary += f"Archivos principales: {files_list_str}."
    return summary

def main():
    parser = argparse.ArgumentParser(
        description="Antigravity Voice Notify & Dev Audio Announcer",
        epilog="Ejemplo: python3 scripts/voice_notify.py -- git diff --stat\n"
               "         python3 scripts/voice_notify.py --git-diff"
    )
    parser.add_argument("--git-diff", action="store_true", help="Narrar resumen hablado de cambios en Git")
    parser.add_argument("--message", "-m", help="Mensaje directo a anunciar")
    parser.add_argument("--rate", type=float, default=1.0, help="Velocidad de locución")
    parser.add_argument("command", nargs="*", help="Comando a ejecutar y anunciar sus resultados")

    args = parser.parse_args()

    if args.git_diff:
        diff_text = get_git_diff_summary()
        speak(diff_text, rate=args.rate)
        return

    if args.message:
        speak(args.message, rate=args.rate)
        return

    if args.command:
        # If separated by '--', remove it
        cmd = args.command
        if cmd[0] == "--":
            cmd = cmd[1:]
        exit_code = run_and_announce_command(cmd)
        sys.exit(exit_code)

    parser.print_help()

if __name__ == "__main__":
    main()
