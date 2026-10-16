#!/usr/bin/env python3
"""Turns CHANGELOG.md into release notes and the site's What's new entries.

  scripts/changelog.py release X.Y.Z        # renames "Unreleased" to X.Y.Z with today's date (in place)
  scripts/changelog.py notes X.Y.Z          # prints Markdown notes for the GitHub release
  scripts/changelog.py html X.Y.Z           # inserts the version's <article> into docs/whats-new.html

CHANGELOG.md format: "## X.Y.Z - YYYY-MM-DD" (or "## Unreleased"), an optional "### Headline" (one line in
English, optionally a second one in Spanish),
English bullets, then an optional "### es" block with Spanish bullets.
"""
import datetime
import html
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"
WHATS_NEW = ROOT / "docs" / "whats-new.html"
MARKER = "  <!-- releases -->\n"


def sections():
    text = CHANGELOG.read_text()
    parts = re.split(r"^## ", text, flags=re.M)[1:]
    out = {}
    for part in parts:
        title, _, body = part.partition("\n")
        version, _, date = title.partition(" - ")
        out[version.strip()] = {"date": date.strip(), "body": body}
    return out


def parse(body):
    headline = ""
    headline_es = ""
    # One line in English; an optional second line right under it in Spanish.
    if match := re.search(r"^### Headline\n(.+)\n(?:(.+)\n)?", body, re.M):
        headline = match.group(1).strip()
        headline_es = (match.group(2) or "").strip()
        if headline_es.startswith("#") or headline_es.startswith("-"):
            headline_es = ""
    english, _, spanish = body.partition("### es")
    bullets = lambda chunk: [line[2:].strip() for line in chunk.splitlines() if line.startswith("- ")]
    return headline, headline_es, bullets(english), bullets(spanish)


def release(version):
    text = CHANGELOG.read_text()
    today = datetime.date.today().isoformat()
    if "## Unreleased" not in text:
        sys.exit("CHANGELOG.md has no 'Unreleased' section; write the notes first")
    CHANGELOG.write_text(text.replace("## Unreleased", f"## {version} - {today}", 1))


def notes(version):
    section = sections().get(version) or sys.exit(f"no {version} in CHANGELOG.md")
    headline, _, english, _ = parse(section["body"])
    lines = ([f"**{headline}**", ""] if headline else []) + [f"- {item}" for item in english]
    print("\n".join(lines))


def inline(text):
    """Markdown `code` to <code> and **bold** to <b>, everything else escaped."""
    escaped = html.escape(text, quote=False)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escaped)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)


def appcast_html(version):
    """Release notes as the HTML Sparkle renders in its update dialog."""
    section = sections().get(version) or sys.exit(f"no {version} in CHANGELOG.md")
    headline, _, english, _ = parse(section["body"])
    parts = [f"<p><b>{inline(headline)}</b></p>"] if headline else []
    parts.append("<ul>" + "".join(f"<li>{inline(b)}</li>" for b in english) + "</ul>")
    print("".join(parts))


def html_entry(version):
    section = sections().get(version) or sys.exit(f"no {version} in CHANGELOG.md")
    headline, headline_es, english, spanish = parse(section["body"])
    headline_es = headline_es or headline
    date = datetime.date.fromisoformat(section["date"])
    shown = date.strftime("%B %-d, %Y")
    spanish = spanish or english
    def items(bullets, lang, hidden):
        attr = f'data-{lang}' + (' hidden' if hidden else '')
        rows = "\n".join(f"        <li>{inline(b)}</li>" for b in bullets)
        return f"      <ul {attr}>\n{rows}\n      </ul>\n"
    article = (
        '  <article class="release">\n'
        f'    <time datetime="{date.isoformat()}">{shown}</time>\n'
        "    <div>\n"
        f'      <h2><span data-en>{inline(headline)}</span><span data-es hidden>{inline(headline_es)}</span>'
        f'<span class="ver">{version}</span></h2>\n'
        + items(english, "en", False) + items(spanish, "es", True) +
        "    </div>\n  </article>\n\n"
    )
    page = WHATS_NEW.read_text()
    if f'<span class="ver">{version}</span>' in page:
        sys.exit(f"docs/whats-new.html already has {version}")
    if MARKER not in page:
        sys.exit("docs/whats-new.html is missing the <!-- releases --> marker")
    WHATS_NEW.write_text(page.replace(MARKER, MARKER + article, 1))


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in {"release", "notes", "html", "appcast"}:
        sys.exit(__doc__)
    {"release": release, "notes": notes, "html": html_entry, "appcast": appcast_html}[sys.argv[1]](sys.argv[2])
