# nv27

**nv27** is a simplified [nvALT](https://brettterpstra.com/project/nvalt/): stripped down to the essentials and rebuilt for Apple silicon and current macOS. It keeps what made Notational Velocity and nvALT great — one window, type to search or create, plain text files in a folder, keyboard all the way — and drops features that I wasn't using (or stopped working): sync services, encryption, single database format, and others. What remains is modernized: Intel-only components are replaced, and the interface from the Mac OS X 10.6 era now follows current macOS conventions, with light and dark mode.

nv27 is a separate app, so it runs side by side with the original nvALT.

**[Download nv27](https://github.com/fengypants/nv27/releases/latest)** · [Release notes](RELEASE_NOTES.md) · [Building from source](#building-from-source)

## Contents

- [Requirements](#requirements)
- [What it is](#what-it-is)
- [How nv27 differs from nvALT](#how-nv27-differs-from-nvalt)
  - [Platform](#platform)
  - [Notes are just files](#notes-are-just-files)
  - [Removed features](#removed-features)
  - [Interface updates](#interface-updates)
- [Running alongside nvALT](#running-alongside-nvalt)
- [Customizing the preview](#customizing-the-preview)
- [Building from source](#building-from-source)
- [Known limitations](#known-limitations)
- [Credits and license](#credits-and-license)

## Requirements

Requires an Apple silicon Mac running macOS 14 Sonoma or later (developed and tested on macOS 27).

## What it is

Notational Velocity is a way to take notes quickly using just the keyboard. Press a shortcut to bring up the window and start typing: NV searches all your notes as you type. Use ⌘J and ⌘K (or the arrow keys) to move through the matches, and Return to start editing. If nothing matches, Return creates a new note with what you typed as its title. Every change is saved as you go — there is no Save.

## How nv27 differs from nvALT

### Platform

| | nvALT 2.x | nv27 |
|---|---|---|
| Processor | Intel (runs on Apple silicon only through Rosetta) | Apple silicon only (`arm64`), no Rosetta |
| macOS | 10.6–10.14 era | macOS 14 or later, built with the current SDK |
| Markdown preview | bundled Intel `multimarkdown` 4.7 and `Markdown.pl`, launched on every refresh | rendered in-process with [cmark-gfm](https://github.com/swiftlang/swift-cmark): tables, footnotes, strikethrough, task lists, autolinks, smart punctuation; MultiMarkdown metadata (or YAML front matter) is hidden and headers get MultiMarkdown-style `id`s |
| Hashing and crash-recovery journal | bundled Intel OpenSSL libraries | Apple's CommonCrypto (same on-disk format) |
| Link detection | Intel-only AutoHyperlinks framework | the system's `NSDataDetector` |
| Updates | Sparkle, pointed at the original Intel app | no auto-update; download new versions from Releases |

**Why:** every one of the replaced components was Intel-only or unmaintained, and several no longer work on current macOS at all.

### Notes are just files

nv27 stores every note as an ordinary file in your notes folder — plain text by default (`.txt`, `.text`, `.utf8` and `.md` are recognized), or RTF/HTML if you choose. You can edit, add, rename or delete notes in Finder or any other app, and nv27 picks up the change. There is no database, custom sync or proprietary storage.

- **Single-database storage was removed.** nvALT could keep all notes inside one database file. If you open a folder that uses one (for example a copy of your nvALT notes), nv27 writes every note out as a plain text file and tells you it did.
- **Tags stay with nv27.** Tags are stored on each note file as OpenMeta tags (an extended attribute, as nvALT did), not as Finder tags, so they don't join the system-wide tag list in Finder. Finder tags on imported files aren't brought in.
- **Markdown instead of TaskPaper in the defaults.** New folders recognize `.md` files as notes; `.taskpaper` was dropped from the default list (you can add it back in Settings › Notes).
- The folder also contains a **Notes & Settings** file. It is a cache (note IDs for links, selection and scroll positions, the folder's settings) so nv27 starts quickly; your notes are never stored only there.

### Removed features

| Feature | Why it was removed |
|---|---|
| **Simplenote sync** | It tied the app to a third-party service and an old sync API. To use notes on several Macs, keep your notes folder in iCloud Drive, Dropbox or similar. Folders that were synced still open; the old sync settings are ignored. |
| **Note encryption** | It only ever protected the single-database format, which nv27 no longer uses: notes are plain files. Use FileVault or an encrypted disk image if you need encryption. *An encrypted nvALT database will not open in nv27* — turn encryption off in nvALT first. |
| **Secure Text Entry** | It blocked other apps (password managers, text expanders) from seeing keystrokes system-wide while nv27 was active; macOS already protects password fields itself. |
| **Textile preview** | Relied on a bundled Perl script; Markdown and MultiMarkdown cover the same ground. A saved Textile preview setting switches to MultiMarkdown. |
| **Share on Peg.gd** | It uploaded notes to a third-party web service; nv27 keeps notes on your Mac. |
| **Single-database storage** | See [Notes are just files](#notes-are-just-files). |
| **Convert imported URLs to Markdown / Readability** | Depended on bundled Python 2 scripts, and macOS no longer ships Python 2. Dragging a link onto the notes list still imports the page as plain text. |
| **Custom "nvALT" scrollbars** | The notes list and editor use the standard macOS scrollbars, which follow your System Settings. |
| **File Type (HFS type code) list** | Matched files by classic Mac OS type codes (`TEXT`, `utxt`) that macOS no longer sets. Files are recognized by extension. |
| **Sparkle "Check for Updates…"** | Its feed served the original Intel nvALT. |

### Interface updates

nv27 follows current macOS conventions throughout. In particular:

- **Main window:** the title is centered, and the search/title field spans the window on its own row, drawn like a standard search field with SF Symbols. The notes list has standard column headers, gridlines that no longer drop out, and a thin standard divider between the list and the note. In the side-by-side layout, list entries use a semibold title with the date and preview in the system's secondary text color, as in Mail and Notes.
- **Appearance:** Settings › General › Appearance offers Automatic, Light and Dark. The color schemes (View › Color Schemes, ⌥⌘1–3) all have light and dark variants:
  - **B/W** — black on white, or light gray on near-black.
  - **Low Contrast** — soft charcoal on a warm off-white "paper", or warm light gray on warm charcoal. It switches to B/W when Accessibility's *Increase contrast* is on.
  - **User Scheme** (the default) — your own colors, with separate Light and Dark pairs in Settings › Fonts & Colors; they default to B/W light and Low Contrast dark.
- **Links** in notes are blue in light and dark schemes.
- **Settings** use the standard toolbar with SF Symbols, and every tab is laid out as a standard macOS settings form at one width: right-aligned labels, controls lined up after them, related checkboxes grouped under one label, and explanations in small secondary text. Labels are reworded in plain sentence case, there's a single extensions list with attached +/− and *Set as Default* in its contextual menu, and panels for removed features are gone.
- **Dock and menu bar:** Settings › General › *Show icon in: Dock / Menu bar* applies immediately (no restart); hiding the Dock icon turns on the menu bar icon, an SF Symbol.
- **Preview window:** SF Symbols for lock, print and save.
- **Help menu:** *Keyboard Shortcuts* opens a window listing every shortcut in tables, in standard macOS key order (instead of an RTF document in TextEdit; its text is in `en.lproj/KeyboardShortcuts.md`, translated in the other languages' folders, as nvALT's shortcuts document was). The menu also links to the nv27 repository and the nvALT and Notational Velocity websites.
- **About:** shows nv27, its version and a link to this repository, in the system font.
- Remaining interface text uses the system font (SF Pro); the note body font is yours to choose in Settings › Fonts & Colors (default Helvetica 14).
- **New defaults** (for new users): Helvetica 14 note text, Large list text, no gridlines, the Tab key moves to the next field (Option-Tab indents), and pasted text keeps no styles from other apps.

## Running alongside nvALT

nv27 is a separate app (bundle identifier `io.github.fengypants.nv27`, with a blue "27" badge on its icon), so it keeps its own preferences and never touches nvALT's.

- **Notes:** nv27 starts with its own folder, `~/Library/Application Support/nv27/Notes`. To bring your notes over, quit nvALT, copy its notes folder, and choose the copy in nv27's Settings › Notes. **Don't point both apps at the same folder while both are running** — they would overwrite each other's index and changes.
- **Links:** nv27 registers the `nv27://` URL scheme for note links; `nvalt://` and `nv://` stay with nvALT. Existing `nvalt://` links inside notes still work in nv27.
- **Services:** the Services menu item is "nv27: New Note from Selection" with no default shortcut, so it doesn't take ⌘⇧V from nvALT.

## Customizing the preview

Choose **Preview › Open Custom CSS Folder** to open `~/Library/Application Support/nv27`, which contains `template.html` and `custom.css`. Edit them to change how the preview looks; you can add JavaScript too. Delete or rename them to get the defaults back.

## Building from source

Requirements: an Apple silicon Mac with a recent Xcode (CI builds with Xcode 26 on macOS 26). The app targets macOS 14 and builds for `arm64` only.

1. Open `Notation.xcodeproj` in Xcode. It fetches the one Swift package dependency ([swift-cmark](https://github.com/swiftlang/swift-cmark)) automatically.
2. Choose the **Notation Release** scheme (optimized) or **Notation Develop** (debug), then build and run.

From the command line:

    xcodebuild -project Notation.xcodeproj -scheme "Notation Release" -derivedDataPath build/DerivedData build
    open build/DerivedData/Build/Products/ForBuilding/nv27.app

Builds are signed ad hoc ("Sign to Run Locally"), which is enough to run on the Mac that built them. To distribute, set your own signing team and notarize.

Every push is built by GitHub Actions (`.github/workflows/build.yml`). Debug builds run a UI self-test (`UISelfTest.m`) that checks the editor takes focus when clicked and takes screenshots of the main window, Settings panes and preview in light and dark appearances. The app icon's badge is drawn by `tools/make_icon.py` (run on macOS by `.github/workflows/icon.yml`).

## Known limitations

- **Not notarized:** the app is signed ad hoc, so macOS asks you to approve it once (see [Requirements](#requirements)).
- **No auto-update:** check [Releases](https://github.com/fengypants/nv27/releases) for new versions.
- **TaskPaper** notes are converted for the preview with the system `ruby`; if macOS stops shipping Ruby, they render as plain MultiMarkdown.
- **Encrypted nvALT databases** don't open (see [Removed features](#removed-features)).
- The **Settings › Notes** panel comes from a legacy compiled interface file, so some of its layout is adjusted in code.

## Credits and license

nv27 is maintained by [fengypants](https://github.com/fengypants). It is built on:

- [Notational Velocity](http://notational.net/) by Zachary Schneirov ([source](https://github.com/scrod/nv))
- [nvALT](https://brettterpstra.com/project/nvalt/) by Brett Terpstra and David Halter (Elasticthreads)
- DivineDominion's [MultiMarkdown fork](https://github.com/DivineDominion/nv)

Like Notational Velocity, nv27 is free software under the GNU General Public License v3; see [COPYING.txt](COPYING.txt). Third-party acknowledgments are in [Acknowledgments.txt](Acknowledgments.txt) (also under Help › Acknowledgments).
