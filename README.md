# Calenbar

**Your next meeting, always in the menu bar.**

Calenbar is a small, native macOS menu bar app. It shows the event you're in or the one coming up, with a live countdown, and gets you into the call in one click.

```
 [15] Weekly Sync • in 12m
```

## Install

**→ [hercase.github.io/calenbar](https://hercase.github.io/calenbar/)**: one Download button and the four first-run steps, in English and Spanish. Send that link to anyone.

Requires macOS 14 (Sonoma) or later. The short version:

1. Download **Calenbar.dmg**, open it and drag Calenbar to **Applications**.
2. Open Calenbar. It isn't notarized by Apple yet, so the first time macOS asks you to confirm in **System Settings › Privacy & Security › Open Anyway**. Only once: updates install themselves.
3. Allow access to **Calendars** and **Notifications** when asked.
4. Using Google Calendar or Outlook? Add the account once in **System Settings › Internet Accounts** with **Calendars** turned on.

## Features

- **Next event in the menu bar** with a countdown (`in 12m`, `25m left`, `now`) next to a calendar icon showing today's date. It sizes itself to the free space and stays clear of the notch.
- **One-click Join** for Google Meet, Zoom, Microsoft Teams, Webex, Slack huddles, FaceTime and more. Zoom and Teams open in their apps when installed.
- **Panel** with today's and tomorrow's events, an optional month calendar, world clocks and event details: room, organizer, guests and their answers, the meeting time in each world clock's zone.
- **Heads-up before meetings**: a notification, an optional full-screen alert, and the menu bar flashing red in the last minutes.
- **Skip** an event to hide it from the menu bar and silence its alerts.
- **Unanswered invitations** are marked, with a shortcut to answer them in Google Calendar or Calendar.
- **Updates itself** through [Sparkle](https://sparkle-project.org): a daily check, background download, and "Update available" in the panel. Every update is verified against an EdDSA key embedded in the app before it is installed.
- **Private by design**: events are read from the macOS calendar database and never leave your Mac.
- **Lightweight**: about 9 MB on disk (most of it the updater) and around 45 MB of memory.

## Build from source

Only the Xcode Command Line Tools are needed (`xcode-select --install`).

```sh
scripts/make-signing-cert.sh   # once: local signing identity, keeps macOS permissions across builds
scripts/build.sh               # build, sign and install to ~/Applications
scripts/test.sh                # unit tests
scripts/lint.sh                # swift-format + SwiftLint + translation check
scripts/previews.sh            # render every screen to .notes/previews/*.png (light and dark)
scripts/package.sh             # build dist/Calenbar-<version>.dmg
scripts/release.sh 0.4.0       # tag, build and sign the DMG, publish the release, update the appcast
```

The code is split into `CalenbarCore` (pure logic: which event to show, title formatting, meeting-link detection, time-zone math; fully unit tested) and `Calenbar` (the AppKit/SwiftUI app). Sparkle comes in as a SwiftPM binary dependency; `scripts/build.sh` copies the framework into the bundle and signs it.

### Releasing

`scripts/release.sh X.Y.Z "What changed"` runs the tests and linters, bumps `VERSION`, tags, builds the universal DMG, signs it with the Sparkle EdDSA key from the login keychain, prepends the release to `docs/appcast.xml`, pushes, and creates the GitHub Release (with a stable `Calenbar.dmg` copy for the landing page's Download button). GitHub Pages serves `docs/`, so the appcast goes live about a minute later and every installed copy picks the update up on its next daily check.

The release machine needs the "Calenbar Dev" code-signing identity (`scripts/make-signing-cert.sh`) and the Sparkle private key that matches `SUPublicEDKey` in `Resources/Info.plist`. Back that key up (`$(scripts/sparkle-tools.sh)/generate_keys -x calenbar-sparkle.key`): without it, installed copies can't verify new versions.

## Credits

Made by [Hernan Case](https://hercase.vercel.app/).
