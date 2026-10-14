# nv27 release notes

## 1.0

The first release of nv27, a simple, modern nvALT: stripped down to the essentials — fast search, plain text files in a folder, the keyboard — and rebuilt for Apple silicon and current macOS. It runs side by side with the original nvALT. See the [README](README.markdown) for the full story of what changed and why.

### Install

Requires an Apple silicon Mac with macOS 14 or later.

1. Download **nv27-arm64.zip**, double-click it to unzip, and drag **nv27.app** into Applications.
2. The first time, macOS refuses to open it because it isn't signed with an Apple Developer ID: click **Done**, then go to **System Settings › Privacy & Security**, scroll down and click **Open Anyway**.

### Coming from nvALT

- nv27 is a separate app with its own settings and its own notes folder (`~/Library/Application Support/nv27/Notes`). To use your nvALT notes, quit nvALT, copy its notes folder and choose the copy in **Settings › Notes**. Don't point both apps at the same folder while both are running.
- If your nvALT notes are stored in a single database, nv27 converts them to plain text files when it opens the folder.
- An **encrypted** nvALT database won't open: turn encryption off in nvALT first.
- Note links use `nv27://`; existing `nvalt://` links in your notes still work.

### New and updated

- **Native on Apple silicon**, built with the current macOS SDK; no Rosetta.
- **Notes are just files:** plain text by default; `.md` files are recognized out of the box. Tags are stored on each file as OpenMeta tags, as in nvALT, so they stay separate from Finder tags.
- **Faster Markdown preview** rendered in the app (tables, footnotes, task lists, strikethrough, autolinks); MultiMarkdown metadata is hidden.
- **Light and Dark mode:** an Appearance setting (Automatic, Light, Dark), and every color scheme has light and dark variants. The User Scheme (default) has separate Light and Dark colors in Settings › Fonts & Colors — black on white in light mode and warm light gray on charcoal in dark mode by default. Low Contrast is now a soft "paper" look and follows *Increase contrast*.
- **Modern interface throughout:** centered window title; full-width search field with SF Symbols; standard list headers, gridlines and divider; Mail-style list in the side-by-side layout; blue links; standard Settings toolbar and controls; SF Symbols in the preview window and menu bar; system font everywhere except your note text.
- **Show Dock icon** is a checkbox that applies instantly; hiding the Dock icon shows the menu bar icon.
- **Color scheme shortcuts** are ⌥⌘1–3 in every language (⌘1–9 remain bookmarks).
- **Keyboard Shortcuts** (Help menu) opens a window listing every shortcut, instead of an RTF document in TextEdit.
- **Help menu** links to the nv27 repository and the nvALT and Notational Velocity websites.

### Removed

- Simplenote sync
- Note encryption and Secure Text Entry
- Single-database storage
- Textile preview and Share on Peg.gd
- Convert imported URLs to Markdown / Readability (needed Python 2)
- Custom nvALT scrollbars and the File Type (HFS type code) list
- Sparkle auto-update (download new versions from Releases)

### Fixed

- Missing gridlines in the notes list after partial redraws.
- Unreadable selected-row titles in dark color schemes.
- Green links in dark color schemes (now blue).

### Known limitations

- The app is signed ad hoc, not notarized, so macOS asks you to approve it once.
- There is no auto-update.
- TaskPaper notes rely on the system `ruby` for their preview conversion.
