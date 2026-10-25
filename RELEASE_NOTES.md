# nv27 release notes

## 1.0.4

Editing improvements, two of them from nvALT 3.0, Brett Terpstra's new release of nvALT. To update, quit nv27 and replace nv27.app in Applications with the one from **nv27-arm64.zip**; your notes and settings are kept.

### Changed

- **Markdown completion is on by default**, so ⌘B, ⌘I and ⌘Y put Markdown around the selection (two asterisks for bold, one for italic, two tildes for strikethrough). nv27 stores notes as plain text, which keeps Markdown but loses bold, italic and strikethrough styles. If you turned Markdown completion on or off yourself (⇧⌘M), your choice is kept. ⌘Y also adds Markdown now; it used to style the text even with Markdown completion on.
- **"Preview using Marked" is now "Preview in Marked"**, as in Help › Keyboard Shortcuts, and it's translated in every language.

### Fixed

- **Return on an empty list item now ends the list.** On a line that's only a bullet or number ("- ", "* ", "3. "), Return removes it and leaves the line blank. nv27 used to remove only bullets it had added itself, so you had to delete typed ones by hand.

### Removed

- **The unused password generator.** Notational Velocity's "Insert New Password" command had already been switched off in nvALT, so it couldn't be used.

## 1.0.3

Keyboard navigation in the notes list. To update, quit nv27 and replace nv27.app in Applications with the one from **nv27-arm64.zip**; your notes and settings are kept.

### Changed

- **Home and End** (fn← and fn→ on a MacBook) select the first and last note when the notes list has focus. **Page Up and Page Down** (fn↑ and fn↓) move the selection a page up or down. A page is however many notes fit in the list, so it follows the divider and window size. These keys used to send you to the search field.
- **The down arrow in the search field goes to the first note in the list** and puts focus there, so the selection shows in your accent color instead of gray. It used to move the selection down a row from the note your typing had selected, which looked like skipping a note. To open the note your typing selected, press Return, as before.
- Help › Keyboard Shortcuts lists these in every language.

## 1.0.2

Reliability fixes, several of them from Notational Velocity 2.5.1, which nvALT and nv27 are based on. To update, quit nv27 and replace nv27.app in Applications with the one from **nv27-arm64.zip**; your notes and settings are kept.

### Fixed

- **A note titled "/" crashed nv27** when it was saved. "/" in a title now becomes "-" in the note's filename, the way ":" already did. (Notational Velocity hung on the same title.)
- **Saving a note no longer briefly removes its file.** On APFS, nv27 saved by renaming the note's file and the new version through placeholder names in four steps; a sync service like Dropbox could catch the note missing in between. nv27 now swaps the new version in with a single step.
- **Failed saves no longer leave hidden files in your notes folder.** If a save failed partway, its hidden temporary file (named like `.1234567-890-12`) stayed in the notes folder, and a sync service would copy it. nv27 now removes it straight away, and when it opens a notes folder it moves any such files over an hour old to the Trash.
- **A note renamed or replaced by another app stays the same note.** When Finder, Dropbox or an editor renamed or replaced a note's file, nv27 could see the old name gone a moment before the new one appeared, and treat it as a deleted note plus a new one, losing its bookmarks and dates. nv27 now waits two seconds before treating a missing file as deleted.
- **Find & Replace could crash nv27** when a replacement shortened the note.
- **Closing the tag window with its close button could crash nv27.**
- **Holding Option when opening nv27** to choose a different notes folder could crash it if that folder then failed to open.
- **Pressing ⌘⌫ again while the delete confirmation was showing** queued a second confirmation.
- **Undo after switching notes folders** could act on the note editor's changes instead of the notes list's.

## 1.0.1

Fixes for problems found after 1.0. To update, quit nv27 and replace nv27.app in Applications with the one from **nv27-arm64.zip**; your notes and settings are kept.

### Fixed

- **nv27 could start without showing its window**, with an empty notes list, after you bookmarked a note while nothing was typed in the search field (for example after clicking a note or using ⌘J/⌘K). The bookmark was saved without the note it points to, and loading it stopped nv27's startup, whichever notes folder you chose. Bookmarks now always save their note, and nv27 skips any bookmark it can't read, including ones saved broken by 1.0; re-create those bookmarks. (This bug came from nvALT.)
- **"Check for Updates…" no longer appears** in the nv27 menu. It was left over from nvALT's updater and showed, grayed out, when startup failed.
- **A new install now uses TextEdit as the external editor** (Note › Edit With) until you choose another in Settings › Editing. It used to pick one of the other editors installed on your Mac, such as Byword or BBEdit, seemingly at random.

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
- **Modern interface throughout:** centered window title; full-width search field with SF Symbols; standard list headers, gridlines and divider; Mail-style list in the side-by-side layout; blue links; SF Symbols in the preview window, hotkey panel and menu bar; system font everywhere except your note text.
- **Redesigned Settings:** the standard toolbar, and every tab laid out as a standard macOS settings form at one width, with clearer, translated labels.
- **Show icon in: Dock / Menu bar** (Settings › General) applies instantly; hiding the Dock icon shows the menu bar icon.
- **New defaults** for new users: Helvetica 14 note text, Large list text, no gridlines, Tab moves to the next field (Option-Tab indents), and pasted text keeps no styles.
- **Color scheme shortcuts** are ⌥⌘1–3 in every language (⌘1–9 remain bookmarks).
- **Keyboard Shortcuts** (Help menu) opens a window listing every shortcut, instead of an RTF document in TextEdit, translated into all of nv27's languages. A new notes folder also gets an up-to-date shortcuts note, and its welcome notes describe nv27.
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
- The Services menu item now appears translated (its translations still used nvALT's name, so none applied).
- The External Text Editor setting's label was hidden until an editor had been chosen.

### Known limitations

- The app is signed ad hoc, not notarized, so macOS asks you to approve it once.
- There is no auto-update.
- TaskPaper notes rely on the system `ruby` for their preview conversion.
