#!/usr/bin/env python3
"""Checks the words of Koncluí's screens (docs/konclui/UX.md section 5) against the repo, with no build.

  python3 scripts/konclui/test-copy.py            # run after `python3 scripts/konclui/rebrand.py`

1. The copy rules (scripts/konclui/rebrand_copy.py) apply with no stale rule and a second pass changes nothing.
2. pt-BR: no dash, no French guillemets, none of the words the glossary retired ("ilha", "island", "pílula", "slots",
   "Configurações", "Koncluí Flow") in a string some Swift file shows. "GOWA" stays only in the gateway's own details.
3. Every language: the dashes left in strings that Swift shows are counted and listed (target: 0 in the hub window, the
   notch and the menus).
4. The permission prompts: InfoPlist.xcstrings is the table of rebrand_copy_data.py, in 14 languages, and project.yml's
   English is the table's English.
5. Every new catalog key the FIXED rules point Swift at exists in the 14 languages.
"""
from __future__ import annotations

import collections
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import rebrand_copy as rc  # noqa: E402

CATALOG = ROOT / "NotchBuddy/Resources/Localizable.xcstrings"
DASH = re.compile(r"[—–]")
# "GOWA" is the gateway's name under Details (UX.md glossary): the installer's progress and the Advanced fields keep it.
GOWA_ALLOWED = {"whatsapp.install.hint", "whatsapp.install.ready %@", "whatsapp.install.ready-custom", "whatsapp.autostart",
                "whatsapp.autostart.hint", "whatsapp.autostart.path", "whatsapp.credential.gowa"}
PT_RETIRED = re.compile(r"(?i:\bilha\b|\bpílulas?\b|\bslots?\b)|(?<!Dynamic )\bIsland\b|(?i:\bisland\b)(?<!Dynamic Island)|"
                        r"(?<!WhatsApp › )\bConfigurações\b|Koncluí Flow|«|»")
# A lone "—" is the glyph a value shows when it has none, not punctuation.
NOT_PUNCTUATION = {"—"}


def source_text() -> str:
    parts = []
    for folder in ("App", "CoucouKit"):
        for path in sorted((ROOT / "NotchBuddy/Sources" / folder).rglob("*.swift")):
            parts.append(path.read_text(encoding="utf-8"))
    return "\n".join(parts)


def referenced(key: str, sources: str) -> bool:
    """A Swift file mentions the catalog key as a literal (interpolations and %@/%lld become wildcards)."""
    if f'"{key}"' in sources:
        return True
    if "%" in key:
        pattern = re.escape(key.replace("\\", "\\\\"))
        pattern = re.sub(r"%(?:@|lld|d)", r".{0,60}?", pattern.replace("\\ ", " "))
        return re.search('"' + pattern + '"', sources) is not None
    return False


def value(entry: dict, lang: str, key: str) -> str | None:
    unit = entry.get("localizations", {}).get(lang)
    if unit is None:
        return key if lang == "en" else None
    return unit["stringUnit"]["value"] if "stringUnit" in unit else None


def main() -> int:
    errors: list[str] = []
    text = CATALOG.read_text(encoding="utf-8")

    stale: list[str] = []
    once, _ = rc.apply(text, stale)
    errors += [f"stale: {line}" for line in stale]
    twice, changed = rc.apply(once, [])
    if changed:
        errors.append(f"the copy rules are not idempotent: a second pass rewrites {changed} entries")
    catalog = json.loads(once)["strings"]

    sources = source_text()
    shown = {key for key in catalog if referenced(key, sources)}

    # 2. pt-BR glossary
    for key in sorted(shown):
        pt = value(catalog[key], "pt-BR", key)
        if pt is None:
            continue
        if DASH.search(pt):
            errors.append(f"pt-BR {key!r} has a dash: {pt}")
        if PT_RETIRED.search(pt):
            errors.append(f"pt-BR {key!r} uses a retired word: {pt}")
        if re.search(r"\bGOWA\b", pt) and key not in GOWA_ALLOWED:
            errors.append(f"pt-BR {key!r} names GOWA outside the gateway's details: {pt}")
    for key in rc.COPY:
        if key in shown and value(catalog[key], "pt-BR", key) in (None, key) and "pt-BR" not in rc.COPY[key][1]:
            errors.append(f"pt-BR {key!r} is still English")

    # 3. dashes per language in strings Swift shows
    counts: collections.Counter = collections.Counter()
    listed: list[str] = []
    for key in sorted(shown):
        for lang in rc.LANGS:
            v = value(catalog[key], lang, key)
            if v and v not in NOT_PUNCTUATION and DASH.search(v):
                counts[lang] += 1
                listed.append(f"{lang} {key!r}: {v[:90]}")
    print("dashes left in strings that Swift shows, per language:",
          ", ".join(f"{lang} {counts[lang]}" for lang in rc.LANGS))
    for line in listed:
        print("  " + line)
    shown_dashes = sum(counts.values())

    # 4. permission prompts
    info_path = ROOT / "NotchBuddy/Resources/InfoPlist.xcstrings"
    if not info_path.exists() or info_path.read_text(encoding="utf-8") != rc.info_plist_catalog():
        errors.append("InfoPlist.xcstrings is missing or differs from the table in rebrand_copy_data.py (run rebrand.py)")
    for key, per_lang in rc.USAGE.items():
        if set(per_lang) != set(rc.LANGS) or any(not t.strip() for t in per_lang.values()):
            errors.append(f"{key}: not every language has a text")
    project = (ROOT / "NotchBuddy/project.yml").read_text(encoding="utf-8")
    for key, per_lang in rc.USAGE.items():
        found = re.search(rf'^\s+{key}: (".*")$', project, re.M)
        if found and json.loads(found.group(1)) != per_lang["en"]:
            errors.append(f"project.yml {key} is not the English of the table (run rebrand.py)")

    # 5. keys the FIXED rules hand to Swift
    for _, _, new in rc.FIXED:
        for key in re.findall(r'localized: "(konclui\.[^"]+)"', new):
            entry = catalog.get(key)
            if entry is None:
                errors.append(f"FIXED points Swift at {key!r}, which is not in the catalog (run add-strings.py with u2/strings.json)")
            elif set(entry.get("localizations", {})) < set(rc.LANGS):
                errors.append(f"{key!r} is missing languages")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: copy rules apply with no stale rule, pt-BR is free of retired words and dashes in "
          f"{len(shown)} shown strings, prompts in 14 languages; {shown_dashes} dashes remain in other languages' shown strings.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
