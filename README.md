# Calenbar

**Your next meeting, in the menu bar.**

Calenbar is a small, native macOS menu bar app. It shows the event you're in or the one coming up, with a live countdown, and gets you into the call in one click.

```
 [15] Weekly Sync • in 12m
```

## Install

**→ [hercase.github.io/calenbar](https://hercase.github.io/calenbar/)**: one Download button and the four first-run steps, in English and Spanish. Send that link to anyone.

Requires macOS 14 (Sonoma) or later. The short version:

1. Download **Calenbar.dmg**, open it and drag Calenbar to **Applications**.
2. Open Calenbar. It isn't registered with Apple's developer program, so the first time macOS says it "could not verify" the app. Click **Done**, then go to **System Settings › Privacy & Security** and click **Open Anyway**. Only once: updates install themselves.
3. Allow access to **Calendars** and **Notifications** when asked.
4. Using Google Calendar or Outlook? Add the account once in **System Settings › Internet Accounts** with **Calendars** turned on.

## Features

- **Next event in the menu bar** with a countdown (`in 12m`, `25m left`, `now`) next to a calendar icon showing today's date. You choose how far ahead it looks (the next hour, the rest of today, the week). It sizes itself to the free space and stays clear of the notch; right-click it for Open Calendar, Settings and Quit.
- **One-click Join** for Google Meet, Zoom, Microsoft Teams, Webex, Slack huddles, FaceTime and more. Zoom and Teams open in their apps when installed.
- **Panel** with today's and tomorrow's events, an optional month calendar, world clocks and, on click, each event's card: time in your other time zones, Join, room, guests and their answers, notes. A pin keeps the panel open.
- **Heads-up before meetings**: a notification, an optional full-screen alert, and the menu bar flashing red in the last minutes.
- **Skip** an event to hide it from the menu bar and silence its alerts.
- **Unanswered invitations** are marked, with a shortcut to answer them in Google Calendar or Calendar.
- **Updates itself** through [Sparkle](https://sparkle-project.org): a daily check, background download, and "Update available" in the panel. Every update is verified against an EdDSA key embedded in the app before it is installed.
- **Private by design**: events are read from the macOS calendar database and never leave your Mac. The app only goes online to check for a new version once a day and, when you add a world clock, to look the city up in Apple Maps.
- **Small**: a native app of a few megabytes, most of it the updater.

## Contributing

Bug reports and ideas: [open an issue](https://github.com/hercase/calenbar/issues/new). Building, testing and releasing are described in [CONTRIBUTING.md](CONTRIBUTING.md).

## Credits

Made by [Hernan Case](https://hercase.vercel.app/?utm_source=calenbar&utm_medium=github).
