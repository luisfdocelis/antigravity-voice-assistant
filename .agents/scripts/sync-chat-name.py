#!/usr/bin/env python3
"""
sync-chat-name.py — Sincronizador del Estándar de Nomenclatura de Chats para CrowKit 🦅

Actualiza de manera consistente el título de una conversación en las tres capas
de persistencia de Antigravity:
  1. Anotación protobuf (.pbtxt) en ~/.gemini/antigravity/annotations/<cid>.pbtxt
  2. Base de datos SQLite en ~/.gemini/antigravity/conversation_summaries.db
  3. Caché binario protobuf en ~/.gemini/antigravity/agyhub_summaries_proto.pb
"""

import argparse
import glob
import os
import re
import shutil
import sqlite3
import sys

DEFAULT_APP_DATA = os.path.expanduser("~/.gemini/antigravity")


def decode_varint(data: bytes, pos: int):
    res = 0
    shift = 0
    while True:
        b = data[pos]
        pos += 1
        res |= (b & 0x7F) << shift
        shift += 7
        if not (b & 0x80):
            break
    return res, pos


def encode_varint(val: int) -> bytes:
    res = bytearray()
    while val > 0x7F:
        res.append((val & 0x7F) | 0x80)
        val >>= 7
    res.append(val & 0x7F)
    return bytes(res)


def parse_proto(data: bytes):
    pos = 0
    fields = []
    while pos < len(data):
        tag, pos = decode_varint(data, pos)
        field_num = tag >> 3
        wire_type = tag & 0x7
        if wire_type == 0:
            val, pos = decode_varint(data, pos)
            fields.append((field_num, wire_type, val))
        elif wire_type == 1:
            val = data[pos : pos + 8]
            pos += 8
            fields.append((field_num, wire_type, val))
        elif wire_type == 2:
            length, pos = decode_varint(data, pos)
            val = data[pos : pos + length]
            pos += length
            fields.append((field_num, wire_type, val))
        elif wire_type == 5:
            val = data[pos : pos + 4]
            pos += 4
            fields.append((field_num, wire_type, val))
        else:
            break
    return fields


def serialize_proto(fields) -> bytes:
    out = bytearray()
    for fnum, wtype, val in fields:
        tag = (fnum << 3) | wtype
        out.extend(encode_varint(tag))
        if wtype == 0:
            out.extend(encode_varint(val))
        elif wtype == 2:
            out.extend(encode_varint(len(val)))
            out.extend(val)
        elif wtype in (1, 5):
            out.extend(val)
    return bytes(out)


def get_most_recent_cid(app_data_dir: str) -> str:
    # 1. Environment variable
    env_cid = os.environ.get("CONVERSATION_ID", "").strip()
    if env_cid:
        return env_cid

    # 2. Most recent active db in conversations/
    conv_dir = os.path.join(app_data_dir, "conversations")
    if os.path.isdir(conv_dir):
        db_files = glob.glob(os.path.join(conv_dir, "*.db"))
        if db_files:
            db_files.sort(key=os.path.getmtime, reverse=True)
            candidate = os.path.basename(db_files[0]).replace(".db", "")
            return candidate

    # 3. Most recent brain dir
    brain_dir = os.path.join(app_data_dir, "brain")
    if os.path.isdir(brain_dir):
        dirs = [
            os.path.join(brain_dir, d)
            for d in os.listdir(brain_dir)
            if os.path.isdir(os.path.join(brain_dir, d)) and d != "tempmediaStorage"
        ]
        if dirs:
            dirs.sort(key=os.path.getmtime, reverse=True)
            return os.path.basename(dirs[0])

    return ""


def update_annotation(annotations_dir: str, cid: str, title: str) -> bool:
    os.makedirs(annotations_dir, exist_ok=True)
    pbtxt_path = os.path.join(annotations_dir, f"{cid}.pbtxt")
    escaped_title = title.replace('"', '\\"')
    title_clause = f'title:"{escaped_title}"'

    if os.path.exists(pbtxt_path):
        with open(pbtxt_path, "r", encoding="utf-8") as f:
            content = f.read()
        if re.search(r'title:\s*"[^"]*"', content):
            new_content = re.sub(r'title:\s*"[^"]*"', title_clause, content)
        else:
            new_content = f"{title_clause} {content.strip()}\n"
    else:
        new_content = f"{title_clause}\n"

    with open(pbtxt_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    return True


def update_sqlite(db_path: str, cid: str, title: str, workspace_uri: str) -> bool:
    if not os.path.exists(db_path):
        return False

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("SELECT conversation_id FROM conversation_summaries WHERE conversation_id = ?", (cid,))
    row = cur.fetchone()

    if row:
        cur.execute(
            "UPDATE conversation_summaries SET title = ?, preview = ? WHERE conversation_id = ?",
            (title, title, cid),
        )
    else:
        uris_json = f'["{workspace_uri}"]'
        cur.execute(
            """
            INSERT INTO conversation_summaries 
            (conversation_id, title, preview, step_count, last_modified_time, workspace_uris, status, source, project_id, last_user_input_time, app_data_dir, group_id)
            VALUES (?, ?, ?, 1, datetime('now'), ?, 'CASCADE_RUN_STATUS_RUNNING', '', '', datetime('now'), 'antigravity', '')
            """,
            (cid, title, title, uris_json),
        )

    conn.commit()
    conn.close()
    return True


def update_protobuf(pb_path: str, cid: str, title: str) -> bool:
    if not os.path.exists(pb_path):
        return False

    with open(pb_path, "rb") as f:
        pb_data = f.read()

    top_fields = parse_proto(pb_data)
    new_top_fields = []
    found = False

    for fnum, wtype, val in top_fields:
        if fnum == 1 and wtype == 2:
            entry_subfields = parse_proto(val)
            entry_cid = None
            for sf in entry_subfields:
                if sf[0] == 1 and sf[1] == 2:
                    entry_cid = sf[2].decode("utf-8", errors="ignore")
                    break

            if entry_cid == cid:
                found = True
                new_title_bytes = title.encode("utf-8")
                new_entry_subfields = []
                for sf in entry_subfields:
                    if sf[0] == 2 and sf[1] == 2:
                        summary_fields = parse_proto(sf[2])
                        new_summary_fields = []
                        for smf in summary_fields:
                            if smf[0] == 1 and smf[1] == 2:
                                new_summary_fields.append((1, 2, new_title_bytes))
                            else:
                                new_summary_fields.append(smf)
                        new_entry_subfields.append((2, 2, serialize_proto(new_summary_fields)))
                    else:
                        new_entry_subfields.append(sf)
                new_top_fields.append((fnum, wtype, serialize_proto(new_entry_subfields)))
                continue

        new_top_fields.append((fnum, wtype, val))

    if found:
        with open(pb_path, "wb") as f:
            f.write(serialize_proto(new_top_fields))
        return True

    return False


def sync_all(app_data_dir: str, workspace_uri: str):
    annotations_dir = os.path.join(app_data_dir, "annotations")
    db_path = os.path.join(app_data_dir, "conversation_summaries.db")
    pb_path = os.path.join(app_data_dir, "agyhub_summaries_proto.pb")

    if not os.path.isdir(annotations_dir):
        print(f"Directorio de anotaciones no encontrado: {annotations_dir}", file=sys.stderr)
        return

    pbtxt_files = glob.glob(os.path.join(annotations_dir, "*.pbtxt"))
    print(f"\n🔄 Sincronizando {len(pbtxt_files)} anotaciones con SQLite y Protobuf...")
    synced = 0

    for pf in pbtxt_files:
        cid = os.path.basename(pf).replace(".pbtxt", "")
        with open(pf, "r", encoding="utf-8") as f:
            content = f.read()
        m = re.search(r'title:\s*"([^"]*)"', content)
        if m:
            title = m.group(1).replace('\\"', '"')
            update_sqlite(db_path, cid, title, workspace_uri)
            update_protobuf(pb_path, cid, title)
            synced += 1

    print(f"✅ Sincronización completa: {synced} conversaciones actualizadas.\n")


def main():
    parser = argparse.ArgumentParser(description="Sincronizador de nombres de chats para CrowKit")
    parser.add_argument("title", nargs="?", help="Título estandarizado a asignar al chat")
    parser.add_argument("--cid", help="ID de la conversación (UUID). Por defecto se auto-detecta la actual.")
    parser.add_argument("--app-data-dir", default=DEFAULT_APP_DATA, help="Directorio app data de Antigravity")
    parser.add_argument("--workspace", default="file:///home/fernando/Projects/personal/CLionProjects/CrowKit", help="URI del workspace")
    parser.add_argument("--list", action="store_true", help="Listar las conversaciones de CrowKit con sus títulos")
    parser.add_argument("--sync-all", action="store_true", help="Sincronizar todas las anotaciones pbtxt a SQLite y Protobuf")

    args = parser.parse_args()

    app_data_dir = os.path.abspath(args.app_data_dir)
    db_path = os.path.join(app_data_dir, "conversation_summaries.db")
    pb_path = os.path.join(app_data_dir, "agyhub_summaries_proto.pb")
    annotations_dir = os.path.join(app_data_dir, "annotations")

    if args.sync_all:
        sync_all(app_data_dir, args.workspace)
        sys.exit(0)

    if args.list:
        if not os.path.exists(db_path):
            print(f"Base de datos no encontrada: {db_path}", file=sys.stderr)
            sys.exit(1)
        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute(
            "SELECT conversation_id, title, datetime(last_modified_time) FROM conversation_summaries WHERE workspace_uris LIKE '%CrowKit%' ORDER BY last_modified_time DESC"
        )
        rows = cur.fetchall()
        print(f"\n📋 Chats de CrowKit registrados ({len(rows)}):")
        print("-" * 90)
        for idx, (cid, t, dt) in enumerate(rows, 1):
            print(f"[{idx:02d}] {cid} | {dt} | {t}")
        print("-" * 90)
        conn.close()
        sys.exit(0)

    if not args.title:
        print("Error: Se requiere especificar el título del chat.", file=sys.stderr)
        print("Uso: ./sync-chat-name.py \"Wave 3 - v2.4.0 - EPIC 27 - CK-2701: TestServer & TestClient\"", file=sys.stderr)
        print("     ./sync-chat-name.py --sync-all", file=sys.stderr)
        print("     ./sync-chat-name.py --list", file=sys.stderr)
        sys.exit(1)

    cid = args.cid
    if not cid:
        cid = get_most_recent_cid(app_data_dir)

    if not cid:
        print("Error: No se pudo auto-detectar el ID de la conversación. Especifique --cid <UUID>.", file=sys.stderr)
        sys.exit(1)

    title = args.title.strip()

    # 1. Update Annotation .pbtxt
    ann_ok = update_annotation(annotations_dir, cid, title)

    # 2. Update SQLite DB
    db_ok = update_sqlite(db_path, cid, title, args.workspace)

    # 3. Update Protobuf Cache
    pb_ok = update_protobuf(pb_path, cid, title)

    print(f"\n✅ Chat sincronizado exitosamente:")
    print(f"   • ID: {cid}")
    print(f"   • Título: \"{title}\"")
    print(f"   • Anotación (.pbtxt): {'🟢 Actualizado' if ann_ok else '❌ Error'}")
    print(f"   • SQLite DB:          {'🟢 Actualizado' if db_ok else '❌ No encontrada'}")
    print(f"   • Protobuf Cache:     {'🟢 Actualizado' if pb_ok else '⚠️ Omitido / no presente'}")
    print(f"\n💡 Para visualizar el cambio en la interfaz gráfica, presione Ctrl + R (Reload Window).\n")


if __name__ == "__main__":
    main()
