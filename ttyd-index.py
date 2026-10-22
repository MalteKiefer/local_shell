"""Embed a font into ttyd's index page so browsers need no locally installed Nerd Font.

Usage: ttyd-index.py <ttyd.html> <font.ttf> <out.html>
"""
import base64
import sys

FAMILY = "JetBrainsMono NF Web"

src, font, out = sys.argv[1:4]
html = open(src, encoding="utf-8").read()
if "</head>" not in html or "</body>" not in html or "xterm" not in html:
    sys.exit(f"{src} does not look like the ttyd index page")

data = base64.b64encode(open(font, "rb").read()).decode()
style = (
    f'<style>@font-face{{font-family:"{FAMILY}";'
    f'src:url(data:font/ttf;base64,{data}) format("truetype");font-display:block}}</style>'
)
# xterm measures glyphs once; if the font finished loading after that, force a re-measure
script = (
    f"<script>document.fonts.load('16px \"{FAMILY}\"').then(function(){{"
    "var t=window.term;if(!t)return;var f=t.options.fontFamily;"
    "t.options.fontFamily='monospace';t.options.fontFamily=f;t.fit&&t.fit();});</script>"
)
html = html.replace("</head>", style + "</head>", 1).replace("</body>", script + "</body>", 1)
open(out, "w", encoding="utf-8").write(html)
