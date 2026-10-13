# nv27 (nvALT 2 for Apple silicon)

> **This fork** is **nv27**, a modernized, Apple silicon–only build of nvALT for current macOS that runs
> side by side with the original nvALT. **[Download the latest build](https://github.com/fengypants/nvalt/releases/download/latest-build/nv27-arm64.zip)**
> ([install steps](https://github.com/fengypants/nvalt/releases/tag/latest-build)), or see
> [Building on Apple silicon](#building-on-apple-silicon) below.

A collaboration between Brett Terpstra (ttscoff) and David Halter (ElasticThreads) based on [DivineDominion's](github.com/divineDominion/nv) fork. nvALT adds a few features we'd been looking for (and let me get some coding practice).

![Screenshot](http://img.skitch.com/20110520-k5y4i6i3p8ciftq2dbs7rx64e7.jpg)

## Contents

- [Building on Apple silicon](#building-on-apple-silicon)
- [About nvALT](#about-nvalt)
- [What it is](#what-it-is)
- [Additional Features](#additional-features)
- [Customization](#customization)
- [Download](#download)
- [Credits](#credits)

## Building on Apple silicon

Requirements: an Apple silicon Mac and Xcode 16 or later. The app targets macOS 14 and later and is built for `arm64` only (no Rosetta needed).

1. Open `Notation.xcodeproj` in Xcode. Xcode fetches the one Swift package dependency ([swift-cmark](https://github.com/swiftlang/swift-cmark), used for the Markdown preview) automatically.
2. Pick the **Notation Release** scheme (optimized) or **Notation Develop** (debug), then build and run.

From the command line:

    xcodebuild -project Notation.xcodeproj -scheme "Notation Release" -derivedDataPath build/DerivedData build
    open build/DerivedData/Build/Products/ForBuilding/nv27.app

Builds are signed ad hoc ("Sign to Run Locally"), which is enough to run the app on the Mac that built it. To distribute it, set your own signing team and notarize.

What changed from the original Intel build:

- **Markdown/MultiMarkdown preview** is rendered in-process with cmark-gfm (tables, footnotes, strikethrough, task lists, autolinks, smart punctuation) instead of launching the bundled Intel `multimarkdown` 4.7 executable for every refresh. A leading MultiMarkdown metadata block (or YAML front matter) is hidden from the preview, and headers get MultiMarkdown-style `id`s.
- **Hashing and the crash-recovery journal** use Apple's CommonCrypto instead of bundled 32/64-bit Intel OpenSSL libraries. The on-disk format is unchanged.
- **Link detection** in notes uses the system's `NSDataDetector` instead of the Intel-only AutoHyperlinks framework.
- **Sparkle** auto-updates are removed (the old feed serves the original Intel app). The "Check for Updates…" menu items are hidden.
- **HTML import as Markdown** relied on bundled Python 2 scripts, and macOS no longer ships Python 2; HTML files now import as rich text.
- **Removed features:** note encryption (passphrases, keychain storage and the encryption controls in Preferences → Notes → Security; Secure Text Entry remains), Simplenote sync (including its preferences tab and title-bar status menu), the Textile preview mode, and "Share on Peg.gd" in the preview window. Databases that were synced with Simplenote still open; their old sync settings are ignored. **An encrypted database will not open**: turn encryption off in the previous version of nvALT first.
- **TaskPaper** conversion in the preview still uses the system `ruby`; if macOS stops shipping it, TaskPaper notes render as plain MultiMarkdown.

### Running alongside the original nvALT

nv27 is a separate app (bundle identifier `io.github.fengypants.nv27`, with a blue "27" badge on its icon), so it keeps its own preferences and never touches nvALT's:

- **Notes:** it starts with its own folder, `~/Library/Application Support/nv27/Notes`, instead of nvALT's default `Notational Data` folder. To bring your notes over, quit nvALT, copy its notes folder, and choose the copy in nv27's Preferences → Notes. **Don't point both apps at the same folder while both are running**: neither locks its database, so they would overwrite each other's changes.
- **Links:** nv27 registers the `nv27://` URL scheme and uses it for note links; `nvalt://` and `nv://` stay with the original nvALT. Clicking an existing `nvalt://` link inside a note in nv27 still works.
- **Services:** the Services menu item is "nv27: New Note from Selection" and has no default shortcut, so it doesn't take ⌘⇧V away from nvALT (assign one in System Settings → Keyboard → Keyboard Shortcuts → Services if you like).
- **Custom preview CSS/HTML** lives in `~/Library/Application Support/nv27`.

## About nvALT

nvALT is a fork of the original [Notational Velocity][notational] with some additional features and some interface modifications. It is a work in progress. I'm not listing it as a beta, as that would imply that it was on its way to being its own product. It's an experiment, and I hope you enjoy it!

## What it is

Notational Velocity is a way to take notes quickly and effortlessly using just your keyboard. You press a shortcut to bring up the window and just start typing. It will begin searching existing notes, filtering them as you type. You can use &#x2318;-J and &#x2318;-K to move through the list. Enter selects and begins editing. If you're creating a new note, you just type a unique title and press enter to move the cursor into a blank edit area. Check out the descriptions at [notational.net][notational] for a more eloquent synopsis.

## Additional Features

nvALT adds:

* Widescreen (horizontal) layout option
* Shortcut (&#x2318;-&#x2325;-N) to collapse the notes panel
* Markdown and MultiMarkdown support with Preview window
* HTML source code tab in the Preview window for fast copy/paste to blogs, etc.
* Unique interface design changes
* Fixes for a couple of bugs/annoyances
* Customizable HTML and CSS files for the Preview window
    * You can use Javascript in the templates to do a few neat tricks

## Customization

Select "Open Custom CSS Folder" within the Preview menu, and the application's supprt folder will open. You will find two files:` template.html` and `custom.css`. If you're handy with HTML and CSS, feel free to customize these in whatever way you like. You can add Javascript as well, but you'll need to load external scripts from a url or using a full file:// path. If worst comes to worst, you can just delete or rename your customizations and the default files will be put back in place automatically when you select the menu item again.

## Download

More info and a download for the compiled binary can be found at [brettterpstra.com/projects/nvalt](http://brettterpstra.com/projects/nvalt/)

## Credits

* [Notational Velocity][notational]
* Code: The original Notational Velocity [source code][original source] by Zachary Schneirov
* Code: DivineDominion's [MultiMarkdown fork][DivineDominion]
* Inspiration: [Elastic Threads' version](http://elasticthreads.tumblr.com/nv) of Notational Velocity

[notational]: http://notational.net/
[original source]: https://github.com/scrod/nv
[DivineDominion]: https://github.com/DivineDominion/nv

