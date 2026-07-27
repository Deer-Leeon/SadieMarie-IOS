#!/usr/bin/env python3
"""Restore SadieMarie files from Cursor agent transcript JSONL (Write + StrReplace)."""
from __future__ import annotations

import json
import sys
from pathlib import Path
from urllib.parse import unquote

WORKSPACE = Path(__file__).resolve().parents[1]
TRANSCRIPTS = [
    Path.home()
    / ".cursor/projects/Users-leonbuchmiller-Documents-Projects-My-Apps-SadieMarie/agent-transcripts/32a48ca9-910d-4be9-87eb-5258e8f99003/32a48ca9-910d-4be9-87eb-5258e8f99003.jsonl",
    Path.home()
    / ".cursor/projects/Users-leonbuchmiller-Documents-Projects-My-Apps-SadieMarie/agent-transcripts/c5f55877-125d-4759-b4d6-82738c3c540b/c5f55877-125d-4759-b4d6-82738c3c540b.jsonl",
]
HISTORY_ROOT = Path.home() / "Library/Application Support/Cursor/User/History"


def is_sadie_marie_ios_path(path: str) -> bool:
    normalized = unquote(path.replace("file://", ""))
    return "My Apps/SadieMarie" in normalized or normalized.startswith(str(WORKSPACE))


def iter_tool_uses(transcript: Path):
    with transcript.open(encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get("role") != "assistant":
                continue
            content = obj.get("message", {}).get("content")
            if not isinstance(content, list):
                continue
            for item in content:
                if item.get("type") != "tool_use":
                    continue
                yield line_no, item.get("name"), item.get("input") or {}


def restore_from_transcripts() -> tuple[int, int]:
    writes: dict[str, str] = {}
    replaces: list[tuple[str, str, str]] = []

    for transcript in TRANSCRIPTS:
        if not transcript.is_file():
            print(f"skip missing transcript: {transcript}", file=sys.stderr)
            continue
        for _line_no, name, inp in iter_tool_uses(transcript):
            path = inp.get("path")
            if not path or not is_sadie_marie_ios_path(path):
                continue
            if name == "Write":
                writes[path] = inp.get("contents", "")
            elif name == "StrReplace":
                old = inp.get("old_string")
                new = inp.get("new_string")
                if old is not None and new is not None:
                    replaces.append((path, old, new))

    written = 0
    for path, contents in writes.items():
        dest = Path(unquote(path.replace("file://", "")))
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(contents, encoding="utf-8")
        written += 1

    patched = 0
    for path, old, new in replaces:
        dest = Path(unquote(path.replace("file://", "")))
        if not dest.is_file():
            print(f"skip StrReplace (missing file): {dest}", file=sys.stderr)
            continue
        text = dest.read_text(encoding="utf-8")
        if old not in text:
            print(f"skip StrReplace (old_string not found): {dest}", file=sys.stderr)
            continue
        dest.write_text(text.replace(old, new, 1), encoding="utf-8")
        patched += 1

    return written, patched


def restore_from_cursor_history() -> int:
    restored = 0
    if not HISTORY_ROOT.is_dir():
        return 0
    # Skip files that history would downgrade (older snapshots).
    skip_history_basenames = {"BookingsView.swift"}

    for entries_path in HISTORY_ROOT.glob("*/entries.json"):
        try:
            data = json.loads(entries_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            continue
        resource = data.get("resource", "")
        if "My%20Apps/SadieMarie" not in resource and "My Apps/SadieMarie" not in unquote(resource):
            continue
        entries = data.get("entries") or []
        if not entries:
            continue
        latest = max(entries, key=lambda e: e.get("timestamp", 0))
        blob_name = latest.get("id")
        if not blob_name:
            continue
        blob = entries_path.parent / blob_name
        if not blob.is_file():
            continue
        dest = Path(unquote(resource.replace("file://", "")))
        if dest.name in skip_history_basenames:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(blob.read_bytes())
        restored += 1
        print(f"history: {dest}")
    return restored


def main() -> int:
    written, patched = restore_from_transcripts()
    history = restore_from_cursor_history()
    print(f"Wrote {written} files from transcripts, applied {patched} StrReplace ops.")
    print(f"Restored {history} files from Cursor local history.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
