#!/usr/bin/env python3
"""Builds Resources/emoji_index.json from Unicode CLDR emoji annotations (Unicode License v3):
word -> emoji for English, Hindi, Hinglish (hi_Latn), Punjabi (Gurmukhi) and Urdu."""
import json, os, re, sys, unicodedata, urllib.request
import xml.etree.ElementTree as ET

BASE = "https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/%s.xml"
LANGS = {"en": "en", "hi": "hi", "hl": "hi_Latn", "pa": "pa", "ur": "ur", "pk": "pa_Arab",
         # more non-Latin-script languages (Latin-script ones would clash with English words)
         "gu": "gu", "mr": "mr", "bn": "bn", "ta": "ta", "te": "te", "kn": "kn", "ml": "ml", "ne": "ne",
         "ar": "ar", "fa": "fa", "ko": "ko", "ja": "ja", "ru": "ru", "th": "th"}
out_path = os.path.join(os.path.dirname(__file__), "..", "Resources", "emoji_index.json")

KEEP_SMALL = {0x231A, 0x231B, 0x23F0, 0x23F3, 0x2B50}

def skip_emoji(e):
    cps = [ord(c) for c in e]
    first = cps[0]
    # Only pictographic emoji: no punctuation/currency/arrow/media-control symbols
    if first < 0x2600 and first not in KEEP_SMALL: return True
    if 0x2B00 <= first <= 0x2BFF and first not in KEEP_SMALL: return True
    if any(0x1F1E6 <= c <= 0x1F1FF or 0x1F3FB <= c <= 0x1F3FF or c in (0x200D, 0x20E3) for c in cps): return True
    if any(0x2190 <= c <= 0x21FF or 0x2B00 <= c <= 0x2BFF or 0x25A0 <= c <= 0x25FF or 0x1F500 <= c <= 0x1F53D
           or 0x1F170 <= c <= 0x1F1FF or 0x1F7E0 <= c <= 0x1F7FF or 0x2600 <= c <= 0x2605 and False for c in cps): return True
    return e in {"🏁", "🚩", "🏳", "🏴", "🔝", "🔚", "🔙", "🔛", "🔜", "🆗", "🆕", "🆒", "🆓", "🆙", "🔞", "™", "©", "®"}

STOP_EN = set("""the a an and or but if of to in on at by for with from up down out off over under again then than so as is are was were be been
am do does did have has had i me my mine you your yours he him his she her hers it its we us our they them their this that these those
what which who whom when where why how all any both each few more most other some such no nor not only own same too very can will just
don't should now one two three four five six seven eight nine ten like get got let make made go going come back there here yes oh""".split())

def load(code):
    cache = os.path.join("/tmp", "cldr_%s.xml" % code)
    if not os.path.exists(cache):
        urllib.request.urlretrieve(BASE % code, cache)
    return ET.parse(cache).getroot()

index = {}   # lang -> {word: (emoji, nkeywords)}
for lang, code in LANGS.items():
    words = {}
    for a in load(code).iter("annotation"):
        if not a.text or "↑" in a.text: continue
        e = a.get("cp")
        if skip_emoji(e): continue
        if lang == "en":   # English: only the emoji's own name ("fire", "moon", "guitar"), never loose keywords
            n = a.text.strip().lower()
            if a.get("type") == "tts" and n.isalpha() and len(n) > 2 and n not in STOP_EN:
                for form in (n, n + "s"):
                    words.setdefault(form, (e, 1))
            continue
        if a.get("type") == "tts": continue
        kws = [k.strip().lower() for k in a.text.split("|")]
        for k in kws:
            k = unicodedata.normalize("NFC", k)
            if " " in k or len(k) < 2 or not re.search(r"\w", k): continue
            if lang == "en" and k in STOP_EN: continue
            prev = words.get(k)
            if prev is None or len(kws) < prev[1]:
                words[k] = (e, len(kws))
    index[lang] = {k: v[0] for k, v in words.items()}
    print(lang, len(words), file=sys.stderr)

with open(out_path, "w") as f:
    json.dump(index, f, ensure_ascii=False, separators=(",", ":"))
print("wrote", out_path, os.path.getsize(out_path) // 1024, "KB", file=sys.stderr)
