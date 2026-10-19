# RelaxMD — Requirements

Android app (Flutter → APK) for reading and editing Markdown files in right-to-left direction.

## Phases
1. **Requirements** (this document)
2. **Design** — screens, layout, theme, icons
3. **Core build** — viewer, RTL + sensitivity, zoom, search, editor
4. **PDF export + extras**
5. **Release** — signed APK

---

## 1. Core features (v1)

### 1.1 Open Markdown in RTL
- Render `.md` / `.markdown` / `.txt` files with full Markdown support: headings, bold/italic, lists, nested lists, checkboxes, tables, quotes, links, images, horizontal rules, code.
- Layout is mirrored for RTL: bullets/numbers on the right, tables start from the right, quote bar on the right.
- **Code blocks and inline code always stay LTR.**
- Global direction mode: **Auto (uses sensitivity)** / **Force RTL** / **Force LTR**.

### 1.2 RTL Sensitivity bar
Problem: a line with Arabic and many English words gets detected as LTR.

Rule: each block (paragraph, heading, list item, table cell, quote line) is analyzed separately.

```
arabicRatio = arabicWords / (arabicWords + latinWords)
block is RTL  if  arabicRatio >= threshold
```
- Word = token containing letters; Arabic word = contains any Arabic letter. Numbers, symbols, URLs, and code are ignored.
- Slider controls `threshold` from **50% → 0%**:
  - **50% (high sensitivity to English)** — normal majority rule.
  - **Lower** — English words matter less and less; fewer Arabic words are needed to make a line RTL.
  - **0% (minimum)** — any line with at least one Arabic word becomes RTL.
- Lines with **no Arabic at all** stay LTR (unless Force RTL is selected).
- Live update while dragging; value saved globally and can be overridden per file.
- The PDF export uses the same rule and value.

### 1.3 Text zoom
- Pinch-to-zoom on the text plus a font-size slider (e.g. 12–40 sp) and +/- buttons.
- Text reflows (no horizontal scrolling). Zoom is remembered per file.

### 1.4 Search
- Search bar with match counter (`3 / 17`), next/previous, highlight all matches, auto-scroll to the current match.
- **Arabic-aware**: ignores tashkeel (diacritics) and tatweel; treats أ/إ/آ/ا, ة/ه, ى/ي as equal.
- Options: case sensitive, whole word.
- Works in both view mode and editor mode.

### 1.5 View mode / Editor mode
- Toggle button switches between the rendered view and the **raw Markdown editor**.
- Editor is RTL-aware (same sensitivity rule per line); monospace or the chosen font.
- Scroll position is kept approximately in sync when switching modes.

### 1.6 Save as PDF
- **Real-text PDF** (selectable, searchable, small) with the Arabic font embedded and correct letter shaping.
- Uses the current direction, sensitivity, font, and font size (zoom).
- Options: page size (A4 / Letter), margins, light theme forced for print, include page numbers.
- Actions after export: save to Downloads / share / open.

---

## 2. Extra features (v1)

### 2.1 Arabic fonts & typography
- Font picker: Cairo, Tajawal, Amiri, Noto Naskh Arabic (+ system default). Bundled in the app (works offline).
- Line spacing and side margins sliders.

### 2.2 Themes, TOC, resume
- Themes: Light, Dark, Sepia, AMOLED black; follow-system option.
- Table of contents drawer generated from headings, tap to jump.
- Remember last reading position per file.
- Keep screen on while reading (toggle); full-screen reading mode (hide toolbars on scroll).

### 2.3 Files: Open-with, recent, share
- Register as handler for `.md` files: open from WhatsApp, Telegram, Google Drive, Gmail, file managers ("Open with" / share to app).
- In-app file picker; create new file.
- Home screen: recent files + favorites (pin), remove from list.
- Share as `.md`, `.pdf`, or plain text.

### 2.4 Editor tools
- Markdown toolbar: bold, italic, heading, list, numbered list, checkbox, quote, link, table, code.
- Autosave (with "unsaved changes" indicator) + undo/redo.
- Find & replace (Arabic-aware matching).
- Word / character count.

---

## 3. Later (not in v1)
- Tappable checkboxes in view mode.
- LaTeX math and Mermaid diagrams.
- Bookmarks and text highlights.
- Arabic text-to-speech.
- Split live preview (tablet / landscape).

---

## 4. Technical notes
- Flutter (stable), Android min SDK 21+, output: release APK (arm64 + armeabi-v7a, or split per ABI).
- Markdown: parse with the `markdown` package into an AST and render with custom widgets, so direction can be set **per block** (needed for the sensitivity rule).
- PDF: `pdf` + `printing` packages; same AST → PDF widgets with `TextDirection` per block and embedded TTF.
- Storage: `shared_preferences` for settings; small local DB (e.g. `hive`/`sqflite`) for recent files, positions, per-file settings.
- File access: Android intent filters + `receive_sharing_intent` / content URIs; Storage Access Framework for saving back.
- UI language: Arabic + English (app follows device language).

## 5. Design decisions (phase 2)

### Name
- **RelaxMD** — calm, comfortable Markdown reading. Package id: `com.relaxmd.app` (placeholder).

### Icon
- **Concept A (chosen):** rounded square in deep teal `#2F6F62` with a cream page `#F7F3EA` whose lines are aligned to the right. The top line is the accent color (a heading).
- Adaptive Android icon: the page as the foreground, solid teal as the background, plus a monochrome layer for themed icons (Android 13+).

### Style
- Material 3, minimal and calm: the text is the hero, the UI chrome stays quiet and hides while reading.
- No pure white (`#FFFFFF`) or pure black text on white. Warm, low-glare backgrounds with softened text for long sessions.
- Reading defaults: font **Noto Naskh Arabic** 18 sp, line height 1.8, comfortable side margins, max line width ~70 characters on tablets.
- UI font: **Tajawal** (clean on buttons and menus).

### Themes (user can switch; default follows the system light/dark setting)

| Theme | Background | Text | Accent | Use |
|---|---|---|---|---|
| Paper (default light) | `#F7F3EA` | `#2A2723` | `#2F6F62` | Daytime reading |
| Sepia | `#F1E6D0` | `#4A3B2A` | `#8A5A2B` | Long sessions, least eye strain |
| Dim (default dark) | `#1C1D1F` | `#D8D3C8` | `#6FB3A3` | Evening |
| Night (AMOLED) | `#000000` | `#B8B2A6` | `#5E9C8F` | Bed / battery saving |

- Optional: custom accent color picker; warm "night filter" toggle (reduces blue light in the app).

### Settings placement
- The **RTL sensitivity slider** is inside **Reading settings** (bottom sheet opened from the toolbar `Aa` button). Next to it: a live preview line that flips direction as you drag.
- Reading settings sheet groups: Direction (Auto / RTL / LTR + sensitivity) · Text (font, size, line spacing, margins) · Theme.
- The full Settings screen holds app-wide options: default theme, keep screen on, PDF defaults, language.

## 6. Screens (phase 2)
The UI is mirrored for RTL: the back arrow points right, and the main floating buttons sit at the bottom-left.

### 6.1 Home
- Top bar: app name (accent color), search files, Settings.
- **Favorites** section, then **Recent** list. Each card shows the file name, source or date, and reading progress (for example "42% read").
- Long-press a card to pin or unpin, remove it from the list, or share it.
- Bottom-left: **Open file** button (file picker) and **+** (new file).
- Empty state: "Open your first Markdown file" with an Open file button.

### 6.2 Reader (view mode)
- Top bar: back, file name, search, table of contents, `Aa` (reading settings), menu (Export PDF, Share, Favorite, File info).
- Rendered Markdown with per-block direction. Code blocks are LTR on a tinted card, and quotes have the accent bar on the right.
- Bottom: zoom chip (`100%`, tap to reset) and an **Edit** floating button.
- Search mode replaces the top bar with an input, a `3 / 17` counter and up/down arrows. Matches are highlighted in soft yellow.
- The table of contents opens as a drawer from the right.
- Toolbars hide on scroll down and come back on scroll up or tap.

### 6.3 Editor (raw Markdown)
- Top bar: Done (✓, back to reader), file name, undo, redo, find and replace.
- Status line: autosave state and word count.
- Raw text with light syntax tinting (`#`, `**`, `-` in the accent color). Each line gets its direction from the same sensitivity rule.
- Markdown toolbar pinned above the keyboard: bold, italic, heading, list, checkbox, quote, link, table, code.

### 6.4 Reading settings sheet (opened with `Aa`)
- Direction: Auto / RTL / LTR.
- **Sensitivity slider** ("Influence of English words", 50% → 0%) with a live preview line and an RTL/LTR badge that flips while dragging. Only active in Auto.
- Font chips (Noto Naskh, Amiri, Cairo, Tajawal), font size slider, line spacing, margins.
- Theme dots: Paper, Sepia, Dim, Night. The reader behind the sheet updates live.

### 6.5 PDF export
- Live first-page preview.
- Page size (A4 / Letter) and margins.
- Toggles: use current direction and sensitivity (on), use current font and size (on), light background for print (on), page numbers (off).
- Actions: **Save** (to Downloads or a chosen folder) and **Share**. After saving, a snackbar offers "Open".
