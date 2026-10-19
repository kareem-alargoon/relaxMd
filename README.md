# RelaxMD

Calm right-to-left Markdown reader and editor for Android, built with Flutter.
See [REQUIREMENTS.md](REQUIREMENTS.md) for the full feature list and design.

## What works (phase 3: core)
- Open `.md` files (copied into the app so they can be edited and saved).
- Rendered Markdown with **per-block direction**: headings, paragraphs, list items, quotes and table cells each get RTL or LTR on their own. Code is always LTR.
- **RTL sensitivity slider** (Reading settings → `Aa`): 50% = majority rule, lower values make lines RTL even when English words outnumber Arabic ones. Plus Auto / RTL / LTR modes.
- **Zoom**: pinch with two fingers, the `− 100% +` chip, or the "Zoom for this file" slider in Reading settings (shown when a file is open). Saved per file and multiplied with the global font size.
- **Search** with a match counter and next/previous. Ignores tashkeel and tatweel and treats أ/إ/آ/ا, ة/ه, ى/ي as the same letter. Match case and whole word options.
- **Editor**: raw Markdown, marker tinting, autosave, undo/redo, find and replace, word count, Markdown toolbar.
- Table of contents drawer, reading position memory, recent files and favorites.
- Themes (Paper, Sepia, Dim, Night, System), Arabic fonts (Naskh, Amiri, Cairo, Tajawal), font size, line spacing, margins.
- Arabic and English UI (follows the phone language).

Coming in phase 4: PDF export, "Open with" from other apps, sharing, app icon, bundled offline fonts, keep screen on.

## Build the APK

You need Flutter (stable) with the Android SDK, and JDK 17.

```bash
flutter create --org com.relaxmd --project-name relaxmd --platforms android .
```

This generates the Android project files. It skips files that already exist, so the custom `android/app/src/main/AndroidManifest.xml` (internet permission, app name) is kept. Don't pass `--overwrite`.

```bash
flutter pub get
```

```bash
flutter test
```

```bash
flutter build apk --release
```

The APK is at `build/app/outputs/flutter-apk/app-release.apk`. Copy it to your phone and open it to install (allow "Install unknown apps" for your file manager when asked). The release build is signed with the debug key, which is fine for your own phone; a proper signing key comes in phase 5.

To install straight to a phone connected by USB (with USB debugging on):

```bash
flutter install
```

### Build on GitHub instead
This repo is at <https://github.com/kareem-alargoon/relaxMd>. The workflow in `.github/workflows/build-apk.yml` builds the APK on every push to `main` (or from the Actions tab -> Build APK -> Run workflow).

**Getting it onto your phone:** sign in to GitHub in the phone browser once (the repo is private), then open <https://github.com/kareem-alargoon/relaxMd/releases/latest> and tap the `RelaxMD-<run>.apk` asset. Every green build on `main` replaces that file, so the link always serves the newest APK. Android asks you to allow installs from the browser the first time, and to confirm the update afterwards. The run's **Artifacts** section has the same APK as a zip, which is more awkward to unpack on a phone.

## Notes
- Fonts are downloaded from Google Fonts the first time they're used, so the first launch needs internet. Until then the system font is shown.
- The editor uses one direction for the whole text (a Flutter text field can't mix directions per line). The reader uses per-block direction.

## Project layout
```
lib/
  main.dart                     app, themes, localization
  core/direction.dart           RTL sensitivity rule
  core/arabic_search.dart       Arabic-aware search
  core/settings.dart            reading settings (saved)
  core/library.dart             recent files, positions, zoom
  core/themes.dart              Paper / Sepia / Dim / Night palettes
  core/strings.dart             Arabic and English UI text
  markdown/md_renderer.dart     Markdown → widgets with per-block direction
  markdown/markdown_editing_controller.dart   editor tinting and highlights
  screens/                      home, reader, editor, reading settings
test/                           unit and widget tests
samples/sample.md               mixed Arabic/English file for trying the app
```
