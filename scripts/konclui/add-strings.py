#!/usr/bin/env python3
"""Adds Koncluí strings to NotchBuddy/Resources/Localizable.xcstrings without rewriting the rest of the file.

Usage: scripts/konclui/add-strings.py strings.json [more.json ...] [--replace]

Each JSON file maps a key to its translations: {"konclui.x.y": {"en": "...", "pt-BR": "...", ...}}. Every key needs all
the catalog's languages (the ones of an existing Koncluí key). New keys go at the top of "strings", one line each, like the
other konclui.* keys, so upstream's multi-line entries stay untouched and merges stay small. A key that already exists is
left alone unless --replace is given. Several units can hand in their strings this way and one person merges them.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CATALOG = ROOT / "NotchBuddy/Resources/Localizable.xcstrings"
ANCHOR = '  "strings" : {\n'


def line(key: str, values: dict) -> str:
    units = ", ".join(
        f'{json.dumps(lang)} : {{ "stringUnit" : {{ "state" : "translated", "value" : {json.dumps(values[lang], ensure_ascii=False)} }} }}'
        for lang in sorted(values)
    )
    return f'    {json.dumps(key, ensure_ascii=False)} : {{ "extractionState" : "manual", "localizations" : {{ {units} }} }},\n'


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    replace = "--replace" in sys.argv
    if not args:
        print(__doc__)
        return 2
    text = CATALOG.read_text(encoding="utf-8")
    catalog = json.loads(text)["strings"]
    languages = sorted(next(v for k, v in catalog.items() if k.startswith("konclui."))["localizations"])

    incoming: dict = {}
    for path in args:
        incoming.update(json.loads(pathlib.Path(path).read_text(encoding="utf-8")))

    problems = [f"{k}: missing {sorted(set(languages) - set(v))}" for k, v in incoming.items() if set(v) != set(languages)]
    if problems:
        print("Not every language is there:\n  " + "\n  ".join(problems), file=sys.stderr)
        return 1

    lines = text.splitlines(keepends=True)
    added = replaced = skipped = 0
    for key, values in incoming.items():
        if key in catalog:
            if not replace:
                skipped += 1
                continue
            prefix = f"    {json.dumps(key, ensure_ascii=False)} : "
            index = next((i for i, l in enumerate(lines) if l.startswith(prefix) and l.rstrip().endswith("},")), None)
            if index is None:
                print(f"{key}: exists as a multi-line entry; edit it by hand", file=sys.stderr)
                return 1
            lines[index] = line(key, values)
            replaced += 1
        else:
            lines.insert(lines.index(ANCHOR) + 1, line(key, values))
            added += 1

    result = "".join(lines)
    json.loads(result)  # still valid JSON
    CATALOG.write_text(result, encoding="utf-8")
    print(f"added {added}, replaced {replaced}, skipped {skipped} (already there)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
