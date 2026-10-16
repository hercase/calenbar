#!/usr/bin/env python3
"""Prepends a release to the Sparkle appcast, keeping earlier items.

Usage: scripts/appcast.py docs/appcast.xml --version 0.4.0 --build 42 --url <dmg url> --length <bytes>
       --signature <EdDSA signature from sign_update -p> [--minimum-system-version 14.0] [--notes "text" | --notes-html "<p>…</p>"]

Items are plain Sparkle <item>s with an EdDSA-signed enclosure; the DMG stays on GitHub Releases
and only this file lives on GitHub Pages.
"""
import argparse
import datetime
import pathlib
import re
import sys
from xml.sax.saxutils import escape

HEADER = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Calenbar</title>
    <link>https://hercase.github.io/calenbar/</link>
    <description>Updates for Calenbar, the menu bar calendar.</description>
    <language>en</language>
"""
FOOTER = """  </channel>
</rss>
"""


def item_xml(args, published):
    notes = ""
    if args.notes_html:
        notes = f"      <description><![CDATA[{args.notes_html}]]></description>\n"
    elif args.notes:
        notes = f"      <description><![CDATA[<p>{escape(args.notes)}</p>]]></description>\n"
    return (
        "    <item>\n"
        f"      <title>Calenbar {args.version}</title>\n"
        f"      <pubDate>{published}</pubDate>\n"
        f"      <sparkle:version>{args.build}</sparkle:version>\n"
        f"      <sparkle:shortVersionString>{args.version}</sparkle:shortVersionString>\n"
        f"      <sparkle:minimumSystemVersion>{args.minimum_system_version}</sparkle:minimumSystemVersion>\n"
        f"{notes}"
        f'      <enclosure url="{escape(args.url)}" length="{args.length}" type="application/octet-stream"\n'
        f'        sparkle:edSignature="{args.signature}" />\n'
        "    </item>\n"
    )


def existing_items(text):
    """Every <item>…</item> block already in the feed, newest first as written."""
    return re.findall(r"    <item>\n.*?    </item>\n", text, re.S)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("path")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--length", required=True, type=int)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--minimum-system-version", default="14.0")
    parser.add_argument("--notes", default="", help="plain text, shown as one paragraph")
    parser.add_argument("--notes-html", default="", help="ready-made HTML (see changelog.py appcast), used verbatim")
    parser.add_argument("--date", default=None, help="RFC 822 date; defaults to now (for tests)")
    parser.add_argument("--keep", default=10, type=int, help="older items to keep")
    args = parser.parse_args()

    path = pathlib.Path(args.path)
    old = path.read_text() if path.exists() else ""
    items = existing_items(old)
    if any(f"<sparkle:shortVersionString>{args.version}</sparkle:shortVersionString>" in item for item in items):
        print(f"error: {args.path} already has an item for {args.version}", file=sys.stderr)
        return 1
    published = args.date or datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S +0000")
    items = [item_xml(args, published)] + items[: args.keep]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(HEADER + "".join(items) + FOOTER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
