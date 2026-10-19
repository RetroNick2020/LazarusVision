# MKGUIDE.PY - builds GUIDE.MD and GUIDE.HTML from GUIDESRC.MD and the screens
# GUIDESHOT recorded in GUIDE.SHT.   python3 MKGUIDE.PY   (needs: pip install markdown)
import html, os, re, sys
import markdown

HERE = os.path.dirname(os.path.abspath(__file__))

# CP437 0..31 as their screen glyphs
LOW = ' ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼'

def glyph(b):
    if b < 32: return LOW[b]
    if b == 127: return '⌂'
    return bytes([b]).decode('cp437')

def load_shots(path):
    shots, cur = {}, None
    for line in open(path, encoding='latin-1'):
        line = line.rstrip('\n')
        if line.startswith('@'):
            name, w, h = line[1:].split()
            cur = shots[name] = []
            continue
        chars, attrs = line.split()
        cur.append([(int(chars[i:i+2], 16), int(attrs[i:i+2], 16)) for i in range(0, len(chars), 2)])
    return shots

DESKTOP = 0x17            # the desktop pattern's colours (Theme.Desktop)

CAPTIONS = {
    'hello': 'The Hello form: a label with an access key, an edit field, the default button.',
    'dialog': 'A dialog (BorderStyle bsDialog) with OK as the Default and Cancel as the Cancel button.',
    'lfm': 'The whole LfmDemo form: every control on it comes from LFMDEMO.LFM.',
    'edits': 'Labels with FocusControl; a password field has the focus.',
    'buttons': 'The default button (►◄), a normal one, a disabled one.',
    'checks': 'A group box with check boxes, three radio buttons, a radio group with three columns.',
    'panels': 'A TPanel, a TStaticText with a border, TBevel lines and a box.',
    'lists': 'A list box with a scroll bar, and a check list box.',
    'combo': 'A pick-only combo box, and an editable one with its list open.',
    'memo': 'A memo with Align alClient, word wrap and a selection.',
    'numbers': 'TSpinEdit, TMaskEdit, TScrollBar, TTrackBar and TProgressBar.',
    'screen': 'The whole screen: the menu bar, the desktop with a form, the status bar.',
    'windowmenu': 'A window menu bar (File open) and a window status bar.',
    'popup': 'A pop-up menu on a memo.',
    'pages': 'A page control with three tab sheets.',
    'containers': 'A tool bar, a list (alLeft), a splitter and a scroll box (alClient).',
    'grid': 'A string grid with a title row and right aligned numbers.',
    'listview': 'A list view in report style, sorted by Name, with check boxes and grid lines.',
    'tree': 'A tree view: C: and FPC open, GAMES and TEMP closed.',
    'synedit': 'TSynEdit with the Pascal highlighter: keywords, a directive, a comment over two lines, strings, numbers; a selection.',
    'synqbasic': 'TSynEdit with the QBasic highlighter: a metacommand, labels and a line number, strings, REM, &H numbers.',
    'messagedlg': 'MessageDlg with Yes, No and Cancel.',
    'inputquery': 'InputQuery.',
    'opendialog': 'TOpenDialog with the Text files filter.',
    'colordialog': 'TColorDialog: the 16 colours, light cyan picked.',
    'finddialog': 'TFindDialog (it stays open while you work).',
    'hint': 'A hint window under a tool button.',
    'cascade': 'Application.Cascade (the whole screen).',
    'tile': 'Application.Tile (the whole screen).',
}

def shot_text(rows):
    out = []
    for row in rows:
        s = ''
        for b, a in row:
            s += ' ' if (a == DESKTOP and b == 0xB0) else glyph(b)
        out.append(s.rstrip())
    while out and not out[-1].strip(): out.pop()
    while out and not out[0].strip(): out.pop(0)
    # the desktop column on the left goes too
    lead = min((len(l) - len(l.lstrip(' ')) for l in out if l.strip()), default=0)
    return '\n'.join(l[lead:] for l in out)

def shot_html(name, rows):
    lines = []
    for row in rows:
        parts, run, cur = [], '', None
        for b, a in row:
            if a != cur:
                if run: parts.append('<span class="f%d b%d">%s</span>' % (cur & 15, cur >> 4, html.escape(run)))
                run, cur = '', a
            run += glyph(b)
        if run: parts.append('<span class="f%d b%d">%s</span>' % (cur & 15, cur >> 4, html.escape(run)))
        lines.append(''.join(parts))
    cols = len(rows[0]) if rows else 0
    return ('<figure class="screen" style="--cols:%d">\n<pre aria-label="Screen: %s">%s</pre>\n'
            '<figcaption>%s</figcaption>\n</figure>' %
            (cols, html.escape(name), '\n'.join(lines), html.escape(CAPTIONS.get(name, name))))

# ---------------------------------------------------------------- Pascal colouring
KEYWORDS = set('''and array as begin case class const constructor destructor div do downto else end
except exit finally for function if implementation in inherited interface is mod nil not of or out
override private procedure program property protected public published raise record repeat set shl
shr string then to try type unit until uses var virtual while with xor true false
initialization finalization'''.split())

def pascal_html(code):
    out, i, n = [], 0, len(code)
    while i < n:
        c = code[i]
        if c == '{':
            j = code.find('}', i)
            j = n if j < 0 else j + 1
            out.append('<span class="cm">%s</span>' % html.escape(code[i:j])); i = j
        elif code.startswith('//', i):
            j = code.find('\n', i); j = n if j < 0 else j
            out.append('<span class="cm">%s</span>' % html.escape(code[i:j])); i = j
        elif c == "'":
            j = i + 1
            while j < n:
                if code[j] == "'":
                    if j + 1 < n and code[j + 1] == "'": j += 2; continue
                    break
                j += 1
            out.append('<span class="st">%s</span>' % html.escape(code[i:j + 1])); i = j + 1
        elif c.isalpha() or c == '_':
            j = i
            while j < n and (code[j].isalnum() or code[j] == '_'): j += 1
            w = code[i:j]
            if w.lower() in KEYWORDS: out.append('<span class="kw">%s</span>' % w)
            else: out.append(html.escape(w))
            i = j
        elif c.isdigit() or (c == '$' and i + 1 < n and code[i + 1] in '0123456789abcdefABCDEF'):
            j = i + 1
            while j < n and (code[j].isalnum() or code[j] == '.'): j += 1
            out.append('<span class="nu">%s</span>' % html.escape(code[i:j])); i = j
        else:
            out.append(html.escape(c)); i += 1
    return ''.join(out)

# ---------------------------------------------------------------- build
def main():
    src = open(os.path.join(HERE, 'GUIDESRC.MD'), encoding='utf-8').read()
    shots = load_shots(os.path.join(HERE, 'GUIDE.SHT'))

    # Markdown: the screens as text blocks
    def md_shot(m):
        name = m.group(1)
        return '```text\n%s\n```\n*%s*' % (shot_text(shots[name]), CAPTIONS.get(name, name))
    md = re.sub(r'\{\{shot:(\w+)\}\}', md_shot, src)
    md = md.replace('The screens in this guide are not mock-ups.',
                    'The screens in this guide (here as text; GUIDE.HTML has them in colour) are not mock-ups.')
    open(os.path.join(HERE, 'GUIDE.MD'), 'w', encoding='utf-8').write(md)

    # HTML: Pascal blocks and screens go in after the Markdown conversion
    store = {}
    def keep(htmltext):
        key = 'ZZKEEP%04dZZ' % len(store)
        store[key] = htmltext
        return '\n\n' + key + '\n\n'
    body = re.sub(r'```pascal\n(.*?)```',
                  lambda m: keep('<pre class="code"><code>%s</code></pre>' % pascal_html(m.group(1).rstrip('\n'))),
                  src, flags=re.S)
    body = re.sub(r'```text\n(.*?)```',
                  lambda m: keep('<pre class="code"><code>%s</code></pre>' % html.escape(m.group(1).rstrip('\n'))),
                  body, flags=re.S)
    body = re.sub(r'\{\{shot:(\w+)\}\}', lambda m: keep(shot_html(m.group(1), shots[m.group(1)])), body)
    h = markdown.markdown(body, extensions=['tables', 'toc', 'sane_lists'])
    for k, v in store.items():
        h = h.replace('<p>%s</p>' % k, v).replace(k, v)

    # the title and the first paragraphs become the opening; the contents list the sidebar
    m = re.search(r'<h2 id="contents">Contents</h2>\s*(<ol>.*?</ol>)', h, re.S)
    toc = m.group(1) if m else ''
    h = h.replace(m.group(0), '') if m else h
    title_m = re.search(r'<h1[^>]*>(.*?)</h1>', h)
    h = re.sub(r'<h1[^>]*>.*?</h1>', '', h, count=1)
    first_h2 = h.find('<h2')
    intro, rest = h[:first_h2], h[first_h2:]
    hero = shot_html('screen', shots['screen']).replace('class="screen"', 'class="screen hero-screen"')

    page = TEMPLATE.replace('%TITLE%', title_m.group(1) if title_m else 'FPTUI User Guide')
    page = page.replace('%INTRO%', intro).replace('%HERO%', hero)
    page = page.replace('%TOC%', toc).replace('%BODY%', rest)
    open(os.path.join(HERE, 'GUIDE.HTML'), 'w', encoding='utf-8').write(page)
    print('GUIDE.MD and GUIDE.HTML written,', len(shots), 'screens')

TEMPLATE = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%TITLE%</title>
<style>
:root {
  --paper: #f3f5f8; --ink: #1d2433; --muted: #5b6475; --rule: #d5dae3;
  --accent: #0000aa; --accent2: #007f7f; --codebg: #e8ecf2; --kw: #0000aa; --cm: #6b7280;
  --st: #8a3b00; --nu: #7a1fa2;
  --body: Charter, "Bitstream Charter", "Sitka Text", Cambria, Georgia, serif;
  --head: "Avenir Next", "Segoe UI", "Helvetica Neue", system-ui, sans-serif;
  --mono: "Cascadia Mono", Consolas, "DejaVu Sans Mono", "Liberation Mono", Menlo, monospace;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --paper: #161a22; --ink: #dde2ea; --muted: #9aa3b2; --rule: #2c3340;
    --accent: #7b7bff; --accent2: #55d0d0; --codebg: #1f2531; --kw: #8f8fff; --cm: #8b93a1;
    --st: #f0a868; --nu: #d59af0; color-scheme: dark;
  }
}
* { box-sizing: border-box; }
html { scroll-padding-top: 1rem; }
body { margin: 0; background: var(--paper); color: var(--ink); font: 17px/1.6 var(--body); }
a { color: var(--accent); text-underline-offset: 2px; }
a:focus-visible { outline: 2px solid var(--accent2); outline-offset: 2px; }
.layout { display: grid; grid-template-columns: 15rem minmax(0, 1fr); gap: 3rem;
          max-width: 82rem; margin: 0 auto; padding: 2.5rem 1.5rem 5rem; }
nav.side { position: sticky; top: 1.5rem; align-self: start; max-height: calc(100vh - 3rem);
           overflow: auto; font: 15px/1.45 var(--head); }
nav.side .name { font-weight: 700; letter-spacing: .01em; margin-bottom: .75rem; color: var(--ink); }
nav.side ol { margin: 0; padding-left: 2.1rem; color: var(--muted); }
nav.side li { margin: .15rem 0; }
nav.side a { color: var(--ink); text-decoration: none; }
nav.side a:hover { color: var(--accent); text-decoration: underline; }
main { min-width: 0; max-width: 50rem; }
header.top h1 { font: 700 2.6rem/1.1 var(--head); margin: 0 0 1rem; letter-spacing: -.01em; }
header.top p { max-width: 38rem; }
h2 { font: 700 1.55rem/1.25 var(--head); margin: 3.5rem 0 .8rem; padding-top: .9rem;
     border-top: 3px solid var(--accent); }
h3 { font: 700 1.15rem/1.3 var(--head); margin: 2rem 0 .5rem; }
p, li { max-width: 40rem; }
code { font: .86em var(--mono); background: var(--codebg); padding: .08em .3em; border-radius: 3px; }
pre.code { background: var(--codebg); padding: .9rem 1.1rem; overflow-x: auto; border-radius: 4px;
           border-left: 3px solid var(--accent2); font: 14px/1.45 var(--mono); }
pre.code code { background: none; padding: 0; font: inherit; }
.kw { color: var(--kw); font-weight: 600; } .cm { color: var(--cm); font-style: italic; }
.st { color: var(--st); } .nu { color: var(--nu); }
table { border-collapse: collapse; margin: 1rem 0 1.5rem; font: 15px/1.45 var(--head); display: block;
        overflow-x: auto; max-width: 100%; }
th, td { border-bottom: 1px solid var(--rule); padding: .4rem .8rem .4rem 0; text-align: left; vertical-align: top; }
th { font-weight: 700; border-bottom: 2px solid var(--ink); }
td code, th code { white-space: nowrap; }

/* the text mode screens: real cells, VGA colours */
figure.screen { margin: 1.4rem 0 2rem; max-width: 100%; }
figure.screen pre { display: inline-block; max-width: 100%; overflow-x: auto; margin: 0;
  font: 15px/normal var(--mono); letter-spacing: 0; background: #000; padding: 10px 12px;
  border-radius: 6px; box-shadow: 0 0 0 1px #000, 0 0 0 7px #3a3f4a, 0 0 0 8px #000; }
figure.screen pre span { display: inline; }
figure.screen figcaption { font: 14px/1.4 var(--head); color: var(--muted); margin-top: .9rem; }
.hero-screen { margin-top: 2rem; }
.hero-screen pre { font-size: 13.5px; }
.f0{color:#000}.f1{color:#0000aa}.f2{color:#00aa00}.f3{color:#00aaaa}.f4{color:#aa0000}.f5{color:#aa00aa}
.f6{color:#aa5500}.f7{color:#aaaaaa}.f8{color:#555555}.f9{color:#5555ff}.f10{color:#55ff55}.f11{color:#55ffff}
.f12{color:#ff5555}.f13{color:#ff55ff}.f14{color:#ffff55}.f15{color:#ffffff}
.b0{background:#000}.b1{background:#0000aa}.b2{background:#00aa00}.b3{background:#00aaaa}.b4{background:#aa0000}
.b5{background:#aa00aa}.b6{background:#aa5500}.b7{background:#aaaaaa}.b8{background:#555555}.b9{background:#5555ff}
.b10{background:#55ff55}.b11{background:#55ffff}.b12{background:#ff5555}.b13{background:#ff55ff}
.b14{background:#ffff55}.b15{background:#ffffff}

@media (max-width: 64rem) {
  .layout { grid-template-columns: minmax(0, 1fr); gap: 0; }
  nav.side { position: static; max-height: none; margin-bottom: 2rem; border-bottom: 1px solid var(--rule);
             padding-bottom: 1.2rem; }
  figure.screen pre { font-size: 12px; }
}
@media (max-width: 40rem) {
  body { font-size: 16px; }
  header.top h1 { font-size: 2rem; }
  figure.screen pre { font-size: 9.5px; padding: 6px; }
}
@media print {
  nav.side { display: none; }
  .layout { display: block; }
  figure.screen pre { box-shadow: none; }
}
</style>
</head>
<body>
<div class="layout">
<nav class="side" aria-label="Contents">
<div class="name">FPTUI User Guide</div>
%TOC%
</nav>
<main>
<header class="top">
<h1>%TITLE%</h1>
%INTRO%
%HERO%
</header>
%BODY%
</main>
</div>
</body>
</html>
'''

if __name__ == '__main__':
    main()
