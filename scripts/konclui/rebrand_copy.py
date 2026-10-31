#!/usr/bin/env python3
"""Koncluí's copy rules: what the screens SAY, kept in the repo so a merge never loses it.

rebrand.py rewrites brand words (Coucou -> Koncluí). This module rewrites the rest of the words a person reads, in the 14
catalog languages, and is called by rebrand.py right after the brand pass (docs/konclui/UX.md, section 5 is the rulebook):

  COPY    {catalog key: the upstream English it replaces + new text per language}. Applied to NotchBuddy/Resources/
          Localizable.xcstrings. Rewrites upstream values, and fills the languages upstream never wrote (Reminders, the Screen
          picker, WhatsApp in de/th/tr...). A rule is STALE, and not applied, when upstream changed its English.
  FILL    {catalog key: {language: text}}: a language upstream has not written yet (WhatsApp in de/th/tr). Never overwrites: once
          upstream writes that language, its text wins and the row is dead weight to delete.
  SUBS    {catalog key: {language: [(old fragment, new fragment)]}}: the same idea for a part of a sentence (a page name,
          "island" -> "notch"), so only the changed words are written down. A fragment found in neither form is STALE.
  DASHES  {key: "sentence" | "colon" | "paren"}: " - " as punctuation becomes a full stop, a colon or parentheses in every
          language (Latin, Cyrillic, Arabic, CJK, Indic, Thai each with their own marks). Listed key by key, never a blanket
          regex: titles, ranges and CJK punctuation break under one.
  PATHS   keys whose navigation arrows ("A -> B") become Apple's separator, one for the whole app.
  FIXED / INSERTS  the same tuples rebrand.py takes: source and project.yml edits for text that no catalog key can reach (a
          hard-coded English literal in an upstream view, the macOS permission prompts).

The data lives in rebrand_copy_data.py. `python3 scripts/konclui/rebrand.py --check` reports 0 changes and 0 stale rules once
everything is applied; scripts/konclui/test-copy.py checks the result (glossary, dashes, format arguments, Info.plist).
"""
from __future__ import annotations

import importlib.util
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CATALOG_REL = "NotchBuddy/Resources/Localizable.xcstrings"

# The shared copy-rule languages, in the order the rows of rebrand_copy_data.py list their texts.
LANGS = ("en", "pt-BR", "es", "fr", "de", "ru", "tr", "id", "ar", "bn", "hi", "th", "zh-Hans", "zh-Hant")

FORMAT = re.compile(r"%(?:\d+\$)?[-+#0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hljztL])?[@diuoxXfFeEgGaAcCsSp]")


def _data():
    spec = importlib.util.spec_from_file_location("rebrand_copy_data", HERE / "rebrand_copy_data.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


DATA = _data()
COPY = DATA.COPY            # {key: (source, {lang: text})}
FILL = DATA.FILL            # {key: {lang: text}}
SUBS = DATA.SUBS            # {key: {lang: [(old, new)]}}
DASHES = DATA.DASHES        # {key: mode}
PATHS = DATA.PATHS          # [key]
FIXED = DATA.FIXED          # [(file, old, new)]
INSERTS = DATA.INSERTS      # [(file, anchor, block)]
USAGE = DATA.USAGE          # {Info.plist key: {lang: text}}
USAGE_LANGS = DATA.USAGE_LANGS
USAGE_KOJA = DATA.USAGE_KOJA


# ---------------------------------------------------------------------------------------------
# Catalog text: find every entry of "strings" so only the ones that change are rewritten

def _string_end(text: str, i: int) -> int:
    j = i + 1
    while text[j] != '"':
        j += 2 if text[j] == "\\" else 1
    return j + 1


def _value_end(text: str, i: int) -> int:
    if text[i] == '"':
        return _string_end(text, i)
    if text[i] in "{[":
        depth, j = 0, i
        while True:
            if text[j] == '"':
                j = _string_end(text, j)
                continue
            if text[j] in "{[":
                depth += 1
            elif text[j] in "}]":
                depth -= 1
                if depth == 0:
                    return j + 1
            j += 1
    j = i
    while text[j] not in ",}] \t\r\n":
        j += 1
    return j


def entry_spans(text: str) -> dict[str, tuple[int, int]]:
    """{key: (start, end)} of each value inside "strings"."""
    i = text.index('"strings"')
    i = text.index("{", i) + 1
    spans: dict[str, tuple[int, int]] = {}
    while True:
        while text[i] in " \t\r\n,":
            i += 1
        if text[i] == "}":
            return spans
        key_end = _string_end(text, i)
        key = json.loads(text[i:key_end])
        i = key_end
        while text[i] in " \t\r\n:":
            i += 1
        end = _value_end(text, i)
        spans[key] = (i, end)
        i = end


def _inline(value, level: int = 0) -> str:
    """The one-line style add-strings.py writes: { "a" : 1, "b" : { "c" : "d" } }."""
    if isinstance(value, dict):
        if not value:
            return "{ }"
        return "{ " + ", ".join(f"{json.dumps(k, ensure_ascii=False)} : {_inline(v)}" for k, v in value.items()) + " }"
    return json.dumps(value, ensure_ascii=False)


def dump_entry(entry: dict, one_line: bool) -> str:
    if one_line:
        return _inline(entry)
    body = json.dumps(entry, indent=2, ensure_ascii=False, separators=(",", " : "))
    return body.replace("\n", "\n    ")


def current(entry: dict, lang: str) -> str | None:
    unit = entry.get("localizations", {}).get(lang)
    if unit is None:
        return None
    return unit["stringUnit"]["value"] if "stringUnit" in unit else None


def english(entry: dict, key: str) -> str:
    return current(entry, "en") or key


def put(entry: dict, lang: str, value: str) -> bool:
    """Sets a language's text; False when that language is a plural/device variation (left alone)."""
    loc = entry.setdefault("localizations", {})
    if lang in loc and "stringUnit" not in loc[lang]:
        return False
    loc[lang] = {"stringUnit": {"state": "translated", "value": value}}
    return True


def arguments(value: str) -> list[str]:
    return sorted(FORMAT.findall(value.replace("%%", "")))


# ---------------------------------------------------------------------------------------------
# Dashes

_LATIN_CASED = {"en", "pt-BR", "es", "fr", "de", "ru", "tr", "id"}
_ENDS = ".!?…。！？।)"


def _upper_first(text: str, lang: str) -> str:
    if not text or lang not in _LATIN_CASED:
        return text
    first = text[0]
    if lang == "tr" and first == "i":
        return "İ" + text[1:]
    return first.upper() + text[1:]


def convert_dash(value: str, lang: str, mode: str) -> str:
    """One " — " as punctuation -> the mark of `mode` in `lang`. Values without a dash come back unchanged."""
    m = re.search(r"\s*—+\s*", value)
    if not m:
        return value
    head, tail = value[:m.start()], value[m.end():]
    if mode == "colon":
        if lang in ("zh-Hans", "zh-Hant"):
            return head + "：" + tail
        return head + (" : " if lang == "fr" else ": ") + tail
    if mode == "paren":
        tail = tail.rstrip(".")
        if lang in ("zh-Hans", "zh-Hant"):
            return head + "（" + tail + "）"
        return f"{head} ({tail})"
    if mode == "sentence":
        stop = {"zh-Hans": "。", "zh-Hant": "。", "hi": "।", "bn": "।", "th": ""}.get(lang, ".")
        head_end = head[-1:] in _ENDS + ":" if head else False
        sep = "" if head_end else stop
        gap = "" if lang in ("zh-Hans", "zh-Hant") else " "
        out = head + sep + gap + _upper_first(tail, lang)
        if stop and out[-1:] not in _ENDS:
            out += stop
        return out
    raise ValueError(f"unknown dash mode {mode!r}")


def convert_path(value: str, lang: str) -> str:
    """Navigation arrows between menu names -> Apple's chevron."""
    if lang == "ar":
        return value.replace(" ← ", " ‹ ").replace("←", "‹")
    return value.replace(" → ", " › ").replace("→", "›")


# ---------------------------------------------------------------------------------------------
# The catalog pass

def apply(text: str, stale: list[str] | None = None) -> tuple[str, int]:
    """Applies COPY, DASHES and PATHS to Localizable.xcstrings text. Returns (new text, entries rewritten)."""
    stale = stale if stale is not None else []
    catalog = json.loads(text)["strings"]
    spans = entry_spans(text)
    changed: dict[str, dict] = {}

    def edit(key: str) -> dict:
        if key not in changed:
            changed[key] = json.loads(json.dumps(catalog[key]))
        return changed[key]

    for key, (source, values) in COPY.items():
        if key not in catalog:
            stale.append(f"COPY {key!r}: the key is gone from the catalog")
            continue
        accepted = (source,) if isinstance(source, str) else tuple(source)
        now = english(catalog[key], key)
        if now not in accepted and now != values.get("en"):
            stale.append(f"COPY {key!r}: upstream's English is now {now!r}, the rule replaces {accepted[0]!r}")
            continue
        source = accepted[0]
        entry = edit(key) if any(current(catalog[key], l) != v for l, v in values.items()) else None
        if entry is None:
            continue
        for lang, value in values.items():
            if arguments(value) != arguments(source):
                stale.append(f"COPY {key!r} {lang}: format arguments differ from the English")
                continue
            if not put(entry, lang, value):
                stale.append(f"COPY {key!r} {lang}: that language is a variation, the rule cannot set it")

    for key, per_lang in FILL.items():
        if key not in catalog:
            stale.append(f"FILL {key!r}: the key is gone from the catalog")
            continue
        base = english(catalog[key], key)
        for lang, value in per_lang.items():
            if current(catalog[key], lang) is not None or (key in changed and current(changed[key], lang) is not None):
                continue
            if arguments(value) != arguments(base):
                stale.append(f"FILL {key!r} {lang}: format arguments differ from the English")
                continue
            put(edit(key), lang, value)

    for key, per_lang in SUBS.items():
        if key not in catalog:
            stale.append(f"SUBS {key!r}: the key is gone from the catalog")
            continue
        entry = changed.get(key) or catalog[key]
        for lang, pairs in per_lang.items():
            value = english(entry, key) if lang == "en" else current(entry, lang)
            if value is None:
                stale.append(f"SUBS {key!r} {lang}: no text in that language")
                continue
            new = value
            for old, repl in pairs:
                if old in new:
                    new = new.replace(old, repl)
                elif repl not in new:
                    stale.append(f"SUBS {key!r} {lang}: neither {old!r} nor {repl!r} found")
            if new != value:
                if arguments(new) != arguments(value):
                    stale.append(f"SUBS {key!r} {lang}: format arguments changed")
                    continue
                put(edit(key), lang, new)
                entry = changed[key]

    for key, mode in DASHES.items():
        if key not in catalog:
            stale.append(f"DASHES {key!r}: the key is gone from the catalog")
            continue
        entry = changed.get(key) or catalog[key]
        for lang in LANGS:
            value = current(entry, lang) if lang != "en" else english(entry, key)
            if value is None or "—" not in value:
                continue
            new = convert_dash(value, lang, mode)
            if new != value:
                put(edit(key), lang, new)
                entry = changed[key]

    for key in PATHS:
        if key not in catalog:
            stale.append(f"PATHS {key!r}: the key is gone from the catalog")
            continue
        entry = changed.get(key) or catalog[key]
        for lang in LANGS:
            value = current(entry, lang) if lang != "en" else english(entry, key)
            if value is None:
                continue
            new = convert_path(value, lang)
            if new != value:
                put(edit(key), lang, new)
                entry = changed[key]

    out, last = [], 0
    for key in sorted(changed, key=lambda k: spans[k][0]):
        a, b = spans[key]
        entry = changed[key]
        if "localizations" in entry:
            entry["localizations"] = {l: entry["localizations"][l] for l in sorted(entry["localizations"])}
        out.append(text[last:a])
        out.append(dump_entry(entry, "\n" not in text[a:b]))
        last = b
    out.append(text[last:])
    return "".join(out), len(changed)


def info_plist_catalog() -> str:
    """The text of NotchBuddy/Resources/InfoPlist.xcstrings: all 16 permission locales."""
    strings = {}
    for key in sorted(USAGE):
        strings[key] = {"extractionState": "manual", "localizations": {
            lang: {"stringUnit": {"state": "translated", "value": USAGE[key][lang]}} for lang in sorted(USAGE[key])}}
    doc = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    return json.dumps(doc, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n"
