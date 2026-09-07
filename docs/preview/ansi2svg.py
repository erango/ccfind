#!/usr/bin/env python3
"""Turn captured ANSI terminal output into a self-contained terminal-card SVG."""
import re, sys, html

FG      = "#c9d1d9"
BG      = "#0c1117"
CHROME  = "#161b22"
BORDER  = "#30363d"

# SGR code -> (fill, weight, opacity, background)
STYLES = {
    "1":          ("#e6edf3", 600, 1.0, None),
    "2":          ("#7d8590", 400, 1.0, None),
    "33":         ("#e3b341", 400, 1.0, None),
    "36":         ("#39c5cf", 400, 1.0, None),
    "1;36":       ("#56d4dd", 600, 1.0, None),
    "1;38;5;213": ("#f778ba", 600, 1.0, None),
    "38;5;245":   ("#8b949e", 400, 1.0, None),
    "1;30;43":    ("#1c1c1c", 600, 1.0, "#e3b341"),
    "2;33":       ("#9e7b28", 400, 1.0, None),
}

FONT = ("ui-monospace,'SF Mono',SFMono-Regular,Menlo,Consolas,"
        "'DejaVu Sans Mono','Liberation Mono',monospace")
FS   = 13.5          # font size
CW   = FS * 0.6      # character advance
LH   = 20            # line height
PADX = 22
PADY = 16
BAR  = 34            # title bar height

SGR = re.compile(r"\x1b\[([0-9;]*)m")


def parse(text):
    """-> list of lines, each a list of (column, string, sgr-code)."""
    lines = []
    for raw in text.split("\n"):
        raw = raw.split("\r")[-1]                 # \r rewrites the line
        raw = raw.replace("\x1b[K", "")
        col, cur, runs = 0, "0", []
        pos = 0
        for m in SGR.finditer(raw):
            chunk = raw[pos:m.start()]
            if chunk:
                runs.append((col, chunk, cur))
                col += len(chunk)
            cur = m.group(1) or "0"
            pos = m.end()
        tail = raw[pos:]
        if tail:
            runs.append((col, tail, cur))
        lines.append(runs)
    while lines and not any(t.strip() for _, t, _ in lines[-1]):
        lines.pop()
    return lines


def render(lines, title, cmd, cols):
    body = []
    y = BAR + PADY + FS
    if cmd:
        body.append(
            f'<text x="{PADX}" y="{y:.1f}" xml:space="preserve">'
            f'<tspan fill="#3fb950" font-weight="600">$</tspan>'
            f'<tspan fill="{FG}"> {html.escape(cmd)}</tspan></text>'
        )
        y += LH

    for runs in lines:
        spans, rects = [], []
        for col, text, code in runs:
            fill, weight, opacity, bg = STYLES.get(code, (FG, 400, 1.0, None))
            x = PADX + col * CW
            if bg:
                rects.append(
                    f'<rect x="{x - 1:.1f}" y="{y - FS + 1.5:.1f}" '
                    f'width="{len(text) * CW + 2:.1f}" height="{FS + 4:.1f}" '
                    f'rx="3" fill="{bg}"/>'
                )
            # Give every glyph its own x. Terminal alignment then holds no
            # matter which monospace font the viewer happens to resolve.
            xs = " ".join(f"{x + i * CW:.1f}" for i in range(len(text)))
            spans.append(
                f'<tspan x="{xs}" fill="{fill}" font-weight="{weight}">'
                f'{html.escape(text)}</tspan>'
            )
        if spans:
            body.append("".join(rects))
            body.append(f'<text y="{y:.1f}" xml:space="preserve">{"".join(spans)}</text>')
        y += LH

    w = int(PADX * 2 + cols * CW)
    h = int(y - FS + PADY)
    dots = "".join(
        f'<circle cx="{20 + i * 18}" cy="{BAR / 2}" r="5.5" fill="{c}"/>'
        for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840"))
    )
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" font-family="{FONT}" font-size="{FS}">
  <rect width="{w}" height="{h}" rx="10" fill="{BG}"/>
  <path d="M0 10a10 10 0 0 1 10-10h{w - 20}a10 10 0 0 1 10 10v{BAR - 10}H0Z" fill="{CHROME}"/>
  {dots}
  <text x="{w / 2:.0f}" y="{BAR / 2 + 4:.0f}" text-anchor="middle" font-size="11.5" fill="#7d8590">{html.escape(title)}</text>
  <rect width="{w}" height="{h}" rx="10" fill="none" stroke="{BORDER}"/>
  {chr(10) + "  ".join(body)}
</svg>
'''


if __name__ == "__main__":
    src, dst, title, cmd, cols = sys.argv[1:6]
    with open(src, encoding="utf-8", errors="replace") as fh:
        parsed = parse(fh.read())
    with open(dst, "w", encoding="utf-8") as fh:
        fh.write(render(parsed, title, cmd, int(cols)))
    print(f"wrote {dst}")
