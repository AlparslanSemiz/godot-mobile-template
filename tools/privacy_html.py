#!/usr/bin/env python3
"""Builds docs/store/privacy-policy.html from privacy-policy.md (headings,
paragraphs, bullet lists, **bold**, `code`), self-contained for GitHub Pages.
Run after editing the Markdown: python3 tools/privacy_html.py"""
import html
import pathlib
import re

SRC = pathlib.Path(__file__).resolve().parent.parent / "docs/store/privacy-policy.md"
OUT = SRC.with_suffix(".html")


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)


def main() -> None:
    lines = SRC.read_text(encoding="utf-8").splitlines()
    body, in_list = [], False
    for line in lines:
        if line.startswith("<!--"):
            body.append(line)
            continue
        if in_list and not line.startswith("- "):
            body.append("</ul>")
            in_list = False
        if line.startswith("# "):
            body.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            body.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            if not in_list:
                body.append("<ul>")
                in_list = True
            body.append(f"<li>{inline(line[2:])}</li>")
        elif line.strip():
            body.append(f"<p>{inline(line)}</p>")
    if in_list:
        body.append("</ul>")
    page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy policy</title>
<style>
body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.5; color: #1a1a1a; background: #fff; }
code { background: #f0f0f0; padding: 0 .2em; }
</style>
</head>
<body>
""" + "\n".join(body) + "\n</body>\n</html>\n"
    OUT.write_text(page, encoding="utf-8")
    print(f"privacy_html: wrote {OUT.name}")


if __name__ == "__main__":
    main()
