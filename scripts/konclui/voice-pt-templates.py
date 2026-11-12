#!/usr/bin/env python3
"""Koncluí: which spoken sentences have a Portuguese text (unit U5).

Upstream writes every spoken answer as t("<French>", "<English>") (VoiceActionRunner, VoiceAnswer) and Koncluí looks the
Portuguese up by the English sentence with a "{}" for each \\( ) (NotchBuddy/Sources/App/KoncluiVoicePhrases.swift). A
sentence upstream adds or rewords has no Portuguese entry until someone writes it: it is then said in English. This script
finds those sentences and the entries nothing uses any more.

  python3 scripts/konclui/voice-pt-templates.py --check     exit 1 when a sentence has no Portuguese entry
  python3 scripts/konclui/voice-pt-templates.py --list      every English template, one per line
  python3 scripts/konclui/voice-pt-templates.py --missing   the missing ones as Swift table lines, ready to translate

After an upstream merge: run --check, translate what --missing prints into KoncluiVoicePhrases.swift, run it again.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCES = [
    "NotchBuddy/Sources/App/Voice/VoiceActionRunner.swift",
    "NotchBuddy/Sources/App/Voice/VoiceQuery.swift",
    "NotchBuddy/Sources/App/Voice/VoiceDataSources.swift",
    "NotchBuddy/Sources/App/IslandWindowController.swift",
]
TABLE = "NotchBuddy/Sources/App/KoncluiVoicePhrases.swift"
BEGIN, END = "// BEGIN sentences", "// END sentences"

ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\", "'": "'", "0": "\0"}


def read_string(src: str, i: int) -> tuple[str, int]:
    """src[i] is the opening quote. Returns (template with "{}" for each interpolation, index after the closing quote)."""
    assert src[i] == '"'
    i += 1
    out: list[str] = []
    while i < len(src):
        c = src[i]
        if c == '"':
            return "".join(out), i + 1
        if c == "\\":
            n = src[i + 1]
            if n == "(":
                depth, i = 1, i + 2
                while depth:
                    d = src[i]
                    if d == '"':
                        _, i = read_string(src, i)
                        continue
                    depth += (d == "(") - (d == ")")
                    i += 1
                out.append("{}")
                continue
            if n == "u" and src[i + 2] == "{":
                end = src.index("}", i)
                out.append(chr(int(src[i + 3:end], 16)))
                i = end + 1
                continue
            out.append(ESCAPES.get(n, n))
            i += 2
            continue
        out.append(c)
        i += 1
    raise ValueError("unterminated string")


def skip_space(src: str, i: int) -> int:
    """Past whitespace and // comments."""
    while i < len(src):
        if src[i].isspace():
            i += 1
        elif src.startswith("//", i):
            i = src.find("\n", i)
            if i < 0:
                return len(src)
        else:
            break
    return i


def call_sites(src: str) -> list[tuple[str, str]]:
    """(French template, English template) of every t(fr, en) and voiceSay(language, fr, en) call."""
    found = []
    for m in re.finditer(r"(?<![A-Za-z0-9_.])t\(|voiceSay\([^,]+,", src):
        i = skip_space(src, m.end())
        if i >= len(src) or src[i] != '"':
            continue
        try:
            fr, i = read_string(src, i)
            i = skip_space(src, i)
            if src[i] != ",":
                continue
            i = skip_space(src, i + 1)
            if src[i] != '"':
                continue
            en, _ = read_string(src, i)
        except (ValueError, IndexError):
            continue
        found.append((fr, en))
    return found


def table_entries() -> list[tuple[str, str]]:
    src = (ROOT / TABLE).read_text(encoding="utf-8")
    body = src[src.index(BEGIN) + len(BEGIN):src.index(END)]
    strings, i = [], 0
    while True:
        i = body.find('"', i)
        if i < 0:
            break
        s, i = read_string(body, i)
        strings.append(s)
    if len(strings) % 2:
        sys.exit(f"{TABLE}: odd number of strings between the markers")
    return list(zip(strings[0::2], strings[1::2]))


def swift_literal(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    sites: dict[str, str] = {}
    for rel in SOURCES:
        for fr, en in call_sites((ROOT / rel).read_text(encoding="utf-8")):
            sites.setdefault(en, fr)
    if mode == "--list":
        print("\n".join(sorted(sites)))
        return 0

    entries = table_entries()
    keys = [k for k, _ in entries]
    problems: list[str] = []
    for k in {k for k in keys if keys.count(k) > 1}:
        problems.append(f"duplicate entry: {k!r}")
    for k, v in entries:
        blanks = k.count("{}")
        used = {int(n) for n in re.findall(r"\{(\d+)\}", v)}
        if not used <= set(range(1, blanks + 1)):
            problems.append(f"entry {k!r}: {{n}} outside 1...{blanks} in {v!r}")
    missing = sorted(set(sites) - set(keys))
    unused = sorted(set(keys) - set(sites))

    if mode == "--missing":
        for en in missing:
            print(f"        {swift_literal(en)}: {swift_literal('')},   // fr: {sites[en]}")
        return 0

    for en in missing:
        problems.append(f"no Portuguese for: {en!r}")
    for k in unused:
        problems.append(f"entry no call site uses: {k!r}")
    for line in problems:
        print("  " + line)
    print(f"{len(sites)} spoken sentences, {len(keys)} Portuguese entries, "
          f"{len(missing)} missing, {len(unused)} unused, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
