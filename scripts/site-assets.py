#!/usr/bin/env python3
"""Stamps docs/*.html links to site.css and site.js with a hash of their contents (?v=…).

GitHub Pages lets browsers keep those files for 10 minutes, so without the stamp a visitor can get
new HTML with the old stylesheet. Rewrites in place; --check fails instead when a stamp is stale.
"""
import hashlib
import re
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
ASSETS = ["site.css", "site.js"]


def main() -> None:
    check = "--check" in sys.argv
    stamps = {name: hashlib.sha256((DOCS / name).read_bytes()).hexdigest()[:10] for name in ASSETS}
    stale = []
    for page in sorted(DOCS.glob("*.html")):
        text = page.read_text()
        new = text
        for name, stamp in stamps.items():
            new = re.sub(rf'(["\']){re.escape(name)}(\?v=[0-9a-f]*)?(["\'])', rf"\g<1>{name}?v={stamp}\g<3>", new)
        if new != text:
            stale.append(page.name)
            if not check:
                page.write_text(new)
    if check and stale:
        sys.exit(f"Stale site.css/site.js stamps in {', '.join(stale)}; run scripts/lint.sh")


if __name__ == "__main__":
    main()
