<p align="center">
  <img src="docs/img/icon.png" alt="" width="96" height="96">
</p>

<h1 align="center">Calenbar</h1>

<p align="center">
  <b>Never miss a meeting again.</b><br>
  A countdown to your next meeting next to the clock, an alert that pulls you out of whatever you're doing when it starts, and one click into the call. Free, native, and your calendar never leaves your Mac.
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

## What it solves

- **Late because you lost track of time.** The menu bar always shows what's next and how long you have: `Weekly Sync • in 12m`, then `now`, then `25m left`. In the last five minutes it flashes.
- **Missing the start while deep in something.** When a meeting starts, a card appears in the corner of the screen, even over full-screen apps, with Join and Snooze. Prefer a takeover? Make it full screen.
- **Hunting for the link.** One click, or ⌃⌘J from any app, opens Google Meet, Zoom, Microsoft Teams, Webex, Slack huddles, FaceTime and six more. Zoom and Teams open in their apps.
- **Double bookings you notice too late.** Meetings that share a slot sit together, so you pick one in time.
- **Time zone math.** World clocks in the panel, with offsets and upcoming clock changes; each event shows its time in your other zones.
- **Showing your agenda while sharing your screen.** Hide titles and the bar just says `Meeting • in 12m`.
- **Another account to trust.** There isn't one: Calenbar reads the calendars your Mac already has (Google, Exchange, iCloud) and nothing leaves your Mac. It updates itself. English and Spanish.

## Install

1. [Download Calenbar.dmg](https://github.com/hercase/calenbar/releases/latest/download/Calenbar.dmg) and drag Calenbar to Applications.
2. The first time, macOS says it can't verify the app. Click **Done**, then **System Settings › Privacy & Security › Open Anyway**. Once.
3. Allow access to Calendars and Notifications.

Or, with Homebrew, instead of step 1: `brew install --cask hercase/calenbar/calenbar`.

Step-by-step with pictures: [the install guide](https://hercase.github.io/calenbar/install.html). Release notes: [What's new](https://hercase.github.io/calenbar/whats-new.html).

## Building

Swift Package Manager with the Xcode Command Line Tools; no Xcode needed. [CONTRIBUTING.md](CONTRIBUTING.md) has the scripts, the quality gates and how releases work.

## Credits

Made by Hernan Case at [keis.studio](https://keis.studio/?utm_source=calenbar&utm_medium=github). Updates by [Sparkle](https://sparkle-project.org). [MIT license](LICENSE).
