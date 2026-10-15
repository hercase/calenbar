# Calenbar

**Your next meeting, always in the menu bar.**

Calenbar is a small, native macOS menu bar app. It shows the event you're in or the one coming up, with a live countdown, and gets you into the call in one click.

```
 📹 Weekly Sync • in 12m
```

## Features

- **Next event in the menu bar** with a countdown (`in 12m`, `25m left`, `now`). It sizes itself to the free space and stays clear of the notch.
- **One-click Join** for Google Meet, Zoom, Microsoft Teams, Webex, Slack huddles, FaceTime and more. Zoom and Teams open in their apps when installed.
- **Panel** with today's and tomorrow's events, an optional month calendar, world clocks and event details: room, organizer, guests and their answers.
- **Heads-up before meetings**: a notification, an optional full-screen alert, and the menu bar flashing red in the last minutes.
- **Skip** an event to hide it from the menu bar and silence its alerts.
- **Unanswered invitations** are marked, with a shortcut to answer them in Google Calendar or Calendar.
- **Private by design**: events are read from the macOS calendar database and never leave your Mac.
- **Lightweight**: about 2 MB and around 45 MB of memory.

## Install

Requires macOS 14 (Sonoma) or later.

1. Download the latest **Calenbar-x.y.z.dmg** from [Releases](https://github.com/hercase/calenbar/releases/latest).
2. Open it and drag **Calenbar** to **Applications**.
3. Open Calenbar. It isn't notarized by Apple yet, so the first time macOS asks to confirm: **System Settings › Privacy & Security › Open Anyway**.
4. Allow access to **Calendars** and **Notifications** when asked.

### Using Google Calendar or Outlook?

You don't need to use Apple's Calendar app. Add your account once in **System Settings › Internet Accounts** and turn on **Calendars**; Calenbar reads it from there.

For new invitations to show up quickly, open **Calendar › Settings › Accounts** and set **Refresh Calendars** to **Every minute**.

## Updates

Calenbar checks GitHub once a day. When there's a new version, the panel shows **Update available**: download the new DMG and replace the app in Applications. You can also check from **Settings › About**.

## Build from source

Only the Xcode Command Line Tools are needed (`xcode-select --install`).

```sh
scripts/make-signing-cert.sh   # once: local signing identity, keeps macOS permissions across builds
scripts/build.sh               # build, sign and install to ~/Applications
scripts/test.sh                # unit tests
scripts/lint.sh                # swift-format + SwiftLint
scripts/package.sh             # build dist/Calenbar-<version>.dmg
scripts/release.sh 0.2.0       # tag, build the DMG and publish a GitHub Release
```

The code is split into `CalenbarCore` (pure logic: which event to show, title formatting, meeting-link detection; fully unit tested) and `Calenbar` (the AppKit/SwiftUI app).

## Credits

Made by [Hernán Case](https://hercase.vercel.app/).
