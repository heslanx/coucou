#!/usr/bin/env python3
"""Writes rebrand.py's rules for Koncluí's updater, from the files themselves (docs/konclui/WORKFLOW.md, "Releases").

The updater's files differ from upstream's in many small places (the update service, the team, the konclui-v tags, the
notes page, their tests). Hand-written rules drift; this script derives them: upstream's file after the rules that are
not generated, the fork's file, and the difference as FIXED rules (replaced lines) and INSERTS (added lines; a FIXED rule
whose new text contains the old one would apply again at every run). A Coucou sync then restores the fork's files.

  python3 scripts/konclui/updater-rules.py           rewrite the generated blocks in rebrand.py
  python3 scripts/konclui/updater-rules.py --check   exit 1 if the blocks are stale or a sync would not give the fork's files

Run it after changing one of FILES, then `python3 scripts/konclui/rebrand.py --check`, and commit rebrand.py with them.
Needs the `upstream` remote fetched (`git fetch upstream`).
"""
import difflib
import runpy
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REBRAND = ROOT / "scripts/konclui/rebrand.py"
UPSTREAM = "upstream/main"
FILES = [
    "NotchBuddy/Sources/App/MacUpdate.swift",
    "NotchBuddy/Sources/App/MacUpdater.swift",
    "NotchBuddy/Sources/App/WhatsNew.swift",
    "tests/MacUpdateTests.swift",
    "tests/WhatsNewTests.swift",
]
F_START = "    # >>> updater rules: written by scripts/konclui/updater-rules.py, do not edit by hand\n"
F_END = "    # <<< updater rules\n"
I_START = "    # >>> updater inserts: written by scripts/konclui/updater-rules.py, do not edit by hand\n"
I_END = "    # <<< updater inserts\n"


def upstream(path: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), "show", f"{UPSTREAM}:{path}"], capture_output=True, text=True,
                          check=True).stdout


def without_generated(text: str) -> str:
    """rebrand.py without this script's blocks."""
    for start, end in ((F_START, F_END), (I_START, I_END)):
        while start in text:
            i = text.index(start)
            text = text[:i] + text[text.index(end, i) + len(end):]
    return text


def load(text: str) -> dict:
    sys.path.insert(0, str(REBRAND.parent))
    # rebrand.py loads rebrand_copy.py next to itself: the copy lives in the same folder for a moment.
    with tempfile.NamedTemporaryFile("w", dir=REBRAND.parent, prefix=".updater-rules-", suffix=".py", delete=False) as f:
        f.write(text)
    try:
        return runpy.run_path(f.name, run_name="updater_rules")
    finally:
        Path(f.name).unlink()


def apply(rules: dict, path: str, text: str) -> str:
    for rel, old, new in rules["FIXED"]:
        if rel == path and old in text:
            text = text.replace(old, new)
    for rel, anchor, block in rules["INSERTS"]:
        if rel == path and block not in text and anchor in text:
            text = text.replace(anchor, block + anchor, 1)
    return text


def derive(base: dict) -> tuple[list, list]:
    fixed, inserts = [], []
    for path in FILES:
        text = apply(base, path, upstream(path))
        cur = (ROOT / path).read_text()
        a, b = text.splitlines(keepends=True), cur.splitlines(keepends=True)
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
            if tag == "equal":
                continue
            if tag == "insert":
                block, k, anchor = "".join(b[j1:j2]), j2, ""
                while True:            # the fork's following lines, as many as it takes to be unique
                    anchor += b[k]
                    k += 1
                    if cur.count(anchor) == 1:
                        break
                inserts.append((path, anchor, block))
                continue
            if tag == "delete":       # keep the line before, so the rule's new text is not empty
                i1 -= 1
                j1 -= 1
            old, new = "".join(a[i1:i2]).rstrip("\n"), "".join(b[j1:j2]).rstrip("\n")
            if text.count(old) != 1 or old in new:
                sys.exit(f"{path}: cannot make a rule of {old!r}; change the line so the new text does not contain it")
            fixed.append((path, old, new))
    return fixed, inserts


def fmt(rules: list) -> str:
    return "".join(f"    ({p!r},\n     {o!r},\n     {n!r}),\n" for p, o, n in rules)


def written(text: str, fixed: list, inserts: list) -> str:
    i = text.index("FIXED = [\n")
    end = text.index("\n]\n", i) + 1                      # the main FIXED list closes here
    text = text[:end] + F_START + fmt(fixed) + F_END + text[end:]
    j = text.index("INSERTS = [\n") + len("INSERTS = [\n")
    return text[:j] + I_START + fmt(inserts) + I_END + text[j:]


def main() -> int:
    current = REBRAND.read_text()
    base_text = without_generated(current)
    fixed, inserts = derive(load(base_text))
    new_text = written(base_text, fixed, inserts)
    rules = load(new_text)
    bad = [p for p in FILES if apply(rules, p, upstream(p)) != (ROOT / p).read_text()]
    if bad:
        print("a sync would not give the fork's files:", *bad, sep="\n  ")
        return 1
    if "--check" in sys.argv:
        if new_text != current:
            print("rebrand.py's updater rules are stale: run python3 scripts/konclui/updater-rules.py")
            return 1
        print(f"updater rules: up to date ({len(fixed)} fixed, {len(inserts)} inserts); a sync gives the fork's files")
        return 0
    REBRAND.write_text(new_text)
    print(f"updater rules: {len(fixed)} fixed, {len(inserts)} inserts written; a sync gives the fork's files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
