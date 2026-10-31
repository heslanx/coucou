#!/usr/bin/env python3
"""Three-way merge of Localizable.xcstrings by key and by language, for a Coucou sync (docs/konclui/WORKFLOW.md).

A line-based merge of the catalog conflicts wherever Koncluí changed a key next to one upstream added. This merges the
JSON instead: per key, per field, per language. When both sides changed the same leaf, upstream's text wins and
`rebrand.py` puts the brand back afterwards; the run lists those leaves. The file keeps its two layouts: Koncluí's
one-line keys at the top (scripts/konclui/add-strings.py), Xcode's layout for the rest.

  python3 scripts/konclui/merge-catalog.py <base> <ours> <theirs> <out>

<base> and <theirs> are the merge base's and upstream's catalogs with rebrand.py applied (sync-remerge.sh makes them),
<ours> is Koncluí's (`git show :2:NotchBuddy/Resources/Localizable.xcstrings`).
"""
import json
import sys
from pathlib import Path


def load(path): return json.loads(Path(path).read_text())

def xcode(value):
    return json.dumps(value, indent=2, separators=(",", " : "), ensure_ascii=False)

def oneline_entries(text):
    """The entries written on one line (Koncluí's, at the top): key -> line."""
    out = {}
    for line in text.splitlines():
        if line.startswith('    "') and (line.endswith("},") or line.endswith("}")):
            try:
                k = json.loads("{" + line.strip().rstrip(",") + "}").popitem()[0]
            except ValueError:
                continue
            out[k] = line.rstrip(",")
    return out

def oneline_keys(text): return list(oneline_entries(text))

def compact(v):
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{json.dumps(k, ensure_ascii=False)} : {compact(x)}" for k, x in v.items()) + " }" if v else "{}"
    if isinstance(v, list):
        return "[ " + ", ".join(compact(x) for x in v) + " ]" if v else "[]"
    return json.dumps(v, ensure_ascii=False)

def merge3(b, o, t, path, conflicts):
    """Deep three-way merge of JSON values; dicts merge per key, anything else picks a side."""
    if o == t: return o
    if o == b: return t
    if t == b: return o
    if isinstance(o, dict) and isinstance(t, dict) and (isinstance(b, dict) or b is MISSING):
        b = {} if b is MISSING else b   # both sides added the key: merge what each added
        out = {}
        keys = list(t.keys()) + [k for k in o.keys() if k not in t]
        for k in keys:
            bv, ov, tv = b.get(k, MISSING), o.get(k, MISSING), t.get(k, MISSING)
            r = merge3(bv, ov, tv, path + [k], conflicts)
            if r is not MISSING: out[k] = r
        return out
    conflicts.append(("/".join(map(str, path)), o, t))
    return t   # both changed a leaf: upstream's text, the brand comes back with rebrand.py

class _Missing:
    def __eq__(self, other): return other is self
    def __hash__(self): return 0
    def __repr__(self): return "MISSING"
MISSING = _Missing()

def render(strings, oneline, ours_text):
    ours_lines = oneline_entries(ours_text)
    parts = []
    for k in oneline:
        if k in strings:
            line = ours_lines[k]
            if json.loads("{" + line.strip() + "}")[k] != strings[k]:
                line = f"    {json.dumps(k, ensure_ascii=False)} : {compact(strings[k])}"
            parts.append(line)
    for k, v in strings.items():
        if k in oneline: continue
        body = xcode(v).replace("\n", "\n    ")
        parts.append(f"    {json.dumps(k, ensure_ascii=False)} : {body}")
    return '{\n  "sourceLanguage" : "en",\n  "strings" : {\n' + ",\n".join(parts) + '\n  },\n  "version" : "1.0"\n}'

def round_trips(text: str) -> bool:
    """Whether render() gives this file back byte for byte: the layout this script writes is the file's own."""
    obj = json.loads(text)
    one = oneline_keys(text)
    strings = {k: obj["strings"][k] for k in one}
    strings.update({k: v for k, v in obj["strings"].items() if k not in strings})
    out = render(strings, one, text)
    return out == text or out + "\n" == text


def main() -> int:
    if len(sys.argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    bpath, opath, tpath, out = sys.argv[1:5]
    for path in (opath, tpath):
        if not round_trips(Path(path).read_text()):
            print(f"merge-catalog: {path} is not in the layout this script writes; merge it by hand", file=sys.stderr)
            return 1
    B, O, T = load(bpath), load(opath), load(tpath)
    ours_text = Path(opath).read_text()
    if not set(B) == set(O) == set(T) == {"sourceLanguage", "strings", "version"}:
        print("merge-catalog: a catalog has top-level fields this script does not know", file=sys.stderr)
        return 1
    conflicts = []
    bs, os_, ts = B["strings"], O["strings"], T["strings"]
    oneline = oneline_keys(ours_text)
    order = list(ts.keys())
    # keys of ours that upstream does not have go where ours had them, after the key before them; the layout of a key
    # (one line or Xcode's) changes only how it is written, never whether it is merged
    for i, k in enumerate(os_.keys()):
        if k in ts:
            continue
        prev = next((p for p in reversed(list(os_.keys())[:i]) if p in order), None)
        order.insert(order.index(prev) + 1 if prev else 0, k)
    merged, removed = {}, []
    for k in order:
        r = merge3(bs.get(k, MISSING), os_.get(k, MISSING), ts.get(k, MISSING), [k], conflicts)
        if r is MISSING:
            removed.append(k)
        else:
            merged[k] = r
    final = {k: merged[k] for k in oneline if k in merged}
    final.update({k: v for k, v in merged.items() if k not in final})
    Path(out).write_text(render(final, oneline, ours_text) + ("\n" if ours_text.endswith("\n") else ""))
    print(f"merge-catalog: keys base {len(bs)}, ours {len(os_)}, theirs {len(ts)}, merged {len(final)}; "
          f"removed {len(removed)}; leaves both sides changed (upstream's kept): {len(conflicts)}")
    for path, o, t in conflicts:
        print(f"  {path}\n    ours:     {str(o)[:100]}\n    upstream: {str(t)[:100]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
