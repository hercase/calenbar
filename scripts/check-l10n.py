#!/usr/bin/env python3
"""Fails when a user-visible string in Sources/ has no entry in a translation table.

Finds keys the same way SwiftUI/Foundation build them: string literals passed to SwiftUI views
(Text, Button, Label, …), .help/.accessibilityLabel, and String(localized:). Interpolations become
format specifiers (%lld for counts, %@ otherwise). Text(verbatim:) is ignored on purpose.

Usage: scripts/check-l10n.py [--keys]   (--keys prints every key found, for writing translations)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LANGUAGES = ["es"]
# Identifier-style keys (long texts) have no English fallback, so they also need an English entry.
ID_KEY = re.compile(r"^[a-z]+(\.[A-Za-z]+)+$")
# Names and handles that stay the same in every language.
NON_TRANSLATABLE = {"Calenbar", "hercase.vercel.app", "github.com/hercase/calenbar", "hercase.github.io/calenbar", "Sparkle"}
LITERAL = r'"((?:[^"\\]|\\.)*)"'
PATTERNS = [
    re.compile(r"String\(localized:\s*" + LITERAL),
    re.compile(r"\b(?:Text|Button|Label|Toggle|Section|LabeledContent|TextField|Picker|Menu|TableColumn|Link|SectionHeader|hint)\(\s*" + LITERAL),
    re.compile(r"\.(?:help|accessibilityLabel)\(\s*" + LITERAL),
]
INTEGER_HINTS = re.compile(r"count|number|minutes|accepted|limit|Int\(|\bday\b", re.IGNORECASE)
INTERPOLATION = re.compile(r"\\\((.*?)\)(?=[^)]*(?:\\\(|$))")


def to_key(literal: str) -> str:
    out, i = [], 0
    while i < len(literal):
        if literal.startswith("\\(", i):
            depth, j = 1, i + 2
            while depth:
                depth += {"(": 1, ")": -1}.get(literal[j], 0)
                j += 1
            expr = literal[i + 2 : j - 1]
            out.append("%lld" if INTEGER_HINTS.search(expr) else "%@")
            i = j
        elif literal.startswith('\\"', i):
            out.append('"')
            i += 2
        else:
            out.append(literal[i])
            i += 1
    return "".join(out)


def source_keys() -> dict[str, str]:
    keys = {}
    for path in sorted((ROOT / "Sources").rglob("*.swift")):
        text = path.read_text()
        for pattern in PATTERNS:
            for match in pattern.finditer(text):
                key = to_key(match.group(1))
                if re.search(r"[A-Za-z]", key) and key not in NON_TRANSLATABLE:
                    line = text.count("\n", 0, match.start()) + 1
                    keys.setdefault(key, f"{path.relative_to(ROOT)}:{line}")
    return keys


def table(language: str) -> dict[str, str]:
    path = ROOT / "Resources" / f"{language}.lproj" / "Localizable.strings"
    entries = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', path.read_text(), re.M)
    return {k.replace('\\"', '"'): v for k, v in entries}


def main() -> int:
    keys = source_keys()
    if "--keys" in sys.argv:
        for key, where in keys.items():
            print(f"{where}\t{key}")
        return 0
    failed = False
    for language in LANGUAGES + ["en"]:
        translations = table(language)
        wanted = keys if language != "en" else {k: w for k, w in keys.items() if ID_KEY.match(k)}
        missing = [(where, key) for key, where in wanted.items() if key not in translations]
        for where, key in missing:
            print(f"{where}: missing {language} translation for {key!r}")
        unused = sorted(set(translations) - set(wanted))
        for key in unused:
            print(f"warning: unused {language} translation {key!r}")
        failed = failed or bool(missing)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
