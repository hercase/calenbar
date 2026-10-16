<p align="center">
  <img src="docs/img/icon.png" alt="" width="96" height="96">
</p>

<h1 align="center">Calenbar</h1>

<p align="center">
  Your next meeting, in the menu bar.<br>
  A small native Mac app: the current or upcoming event next to the clock, with a countdown, and one click to join the call.
</p>

<p align="center">
  <a href="https://github.com/hercase/calenbar/releases/latest/download/Calenbar.dmg"><img alt="Download for Mac" src="https://img.shields.io/badge/Download-for%20Mac-4c4ed6?style=for-the-badge"></a>
</p>

<p align="center">
  <a href="https://github.com/hercase/calenbar/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/hercase/calenbar?label=version&color=4c4ed6"></a>
  <img alt="macOS 14 or later" src="https://img.shields.io/badge/macOS-14%2B-lightgrey">
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-lightgrey"></a>
</p>

<p align="center">
  <img src="docs/img/og.jpg" alt="A Mac menu bar showing “Weekly Sync • in 12m”, with the Calenbar panel open below it" width="900">
</p>

## What it does

- **Always in view.** The menu bar shows today's date and the next event: `Weekly Sync • in 12m`, then `now`, then `25m left`. You choose how far ahead it looks, from the next hour to the whole week.
- **One click to join.** Google Meet, Zoom, Microsoft Teams, Webex, Slack huddles and FaceTime. Zoom and Teams open in their apps when installed.
- **A panel for the day.** Today and tomorrow, a month view, world clocks, and a card per event: the time in your other time zones, the room, who's coming and who said yes, the notes.
- **Hard to miss.** A notification before each meeting, an optional full-screen alert when it starts, and the bar flashing red in the last minutes.
- **Your calendars, as they are.** Works with any account the Mac's Calendar knows (Google, Exchange, iCloud). Events never leave your Mac.
- **Low maintenance.** Updates itself. English and Spanish.

## Install

1. [Download Calenbar.dmg](https://github.com/hercase/calenbar/releases/latest/download/Calenbar.dmg) and drag Calenbar to Applications.
2. The first time, macOS says it can't verify the app. Click **Done**, then **System Settings › Privacy & Security › Open Anyway**. Once.
3. Allow access to Calendars and Notifications.

Step-by-step with pictures: [the install guide](https://hercase.github.io/calenbar/install.html). Release notes: [What's new](https://hercase.github.io/calenbar/whats-new.html).

## Building

Swift Package Manager with the Xcode Command Line Tools; no Xcode needed. [CONTRIBUTING.md](CONTRIBUTING.md) has the scripts, the quality gates and how releases work.

## Credits

Made by [Hernan Case](https://hercase.vercel.app/?utm_source=calenbar&utm_medium=github). Updates by [Sparkle](https://sparkle-project.org). [MIT license](LICENSE).
