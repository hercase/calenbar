# Contributing to Calenbar

## Toolchain

Only the Xcode Command Line Tools are needed (`xcode-select --install`): Swift 6.4 with the macOS SDK. There is no Xcode project; everything is Swift Package Manager plus the scripts below.

Two consequences of building without Xcode:

- SwiftUI's `@State` macro plugin isn't available, so view state lives in `@Observable` classes (`PanelState`, `SettingsUIState`). Don't reintroduce `@State`.
- Swift Testing's macro plugin lives outside the default search path; `scripts/test.sh` passes it in. Run tests through the script, not `swift test` directly.

## Scripts

```sh
scripts/make-signing-cert.sh   # once: local "Calenbar Dev" signing identity, keeps macOS permissions across builds
scripts/build.sh               # release build, sign, install to ~/Applications
scripts/test.sh                # unit tests (CalenbarCore)
scripts/lint.sh                # swift-format, translation check, SwiftLint (--check to fail instead of rewriting)
scripts/previews.sh            # render every screen to .notes/previews/*.png, light and dark
scripts/package.sh             # dist/Calenbar-<version>.dmg
scripts/release.sh 0.5.0 "…"   # tag, build and sign the DMG, publish the release, update the appcast
```

Quality gates, all of which CI runs on every push: `scripts/test.sh`, `scripts/lint.sh --check`, and `swift build` with no warnings. Every user-visible string needs a Spanish entry in `Resources/es.lproj/Localizable.strings`; `scripts/check-l10n.py` (part of `lint.sh`) fails when one is missing.

## Layout

- `Sources/CalenbarCore`: pure logic with no AppKit or EventKit: which event the menu bar shows (`TitleSelector`, `TitleHorizon`), title formatting and width fitting, meeting-link detection, event filtering and deduplication, time-zone math. Fully unit tested in `Tests/CalenbarCoreTests`.
- `Sources/Calenbar`: the app. `App/` wiring and the offscreen preview renderer; `MenuBar/` the status item, date icon and notch-aware width; `Panel/` the popover, event list, card and world clocks; `Alert/` the full-screen reminder; `Settings/`; `Services/` EventKit access, notifications, Sparkle updates, login item, first-launch install check.
- `Resources/`: Info.plist, entitlements, icon, localizations, launchd agent.
- `docs/`: the GitHub Pages site and the Sparkle appcast. Pages link `site.css`/`site.js` with a content hash (`?v=…`) so browsers never pair new HTML with a cached stylesheet; `scripts/lint.sh` refreshes it and CI checks it.

Keep logic in Core with tests; the app layer should be thin.

## Menu bar width

On macOS with a notch, `CGWindowListCopyWindowInfo` no longer reports other apps' status items, so `StatusBarController` learns a title width that only ever shrinks and forces a re-layout when the item lands left of the notch. It is fragile by nature; read it fully before changing it.

## Commits

Plain Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`), small and focused, with no co-author or tool attribution trailers. Don't mention or compare with other calendar or menu bar apps anywhere in the repo.

## Releasing

Write the version's notes in `CHANGELOG.md` under `## Unreleased` (English bullets, optional `### es` block), then run `scripts/release.sh X.Y.Z`. It runs the gates, turns the Unreleased section into the version (with today's date), adds the entry to `docs/whats-new.html`, bumps `VERSION`, tags, builds the universal DMG, signs it with the Sparkle EdDSA key from the login keychain, pushes, creates the GitHub Release with those notes (plus a stable `Calenbar.dmg` copy for the site's Download button), updates the Homebrew cask in `hercase/homebrew-calenbar`, and only then prepends the release to `docs/appcast.xml` and pushes that. GitHub Pages serves `docs/`, so the appcast goes live about a minute later and every installed copy picks the update up on its next daily check.

The release machine needs:

- the "Calenbar Dev" code-signing identity (`scripts/make-signing-cert.sh`), so every build carries the same signature and macOS keeps the Calendar permission across updates;
- the Sparkle private key matching `SUPublicEDKey` in `Resources/Info.plist`. Back it up with `$(scripts/sparkle-tools.sh)/generate_keys -x calenbar-sparkle.key`; import it elsewhere with `generate_keys -i`. Without it no new version can be signed, and regenerating the key would orphan every installed copy.

Pushing commits to `main` is not a release; nothing reaches users until `release.sh` runs.

## Testing an update locally

```sh
CALENBAR_FEED_URL=http://localhost:8765/appcast.xml CALENBAR_BUILD=100 scripts/build.sh   # the "old" app
echo 0.9.9 > VERSION && CALENBAR_BUILD=101 scripts/package.sh && git checkout VERSION   # the "new" DMG
```

Sign the DMG with `sign_update -p`, write an appcast item with `scripts/appcast.py` pointing at `http://localhost:8765/…`, serve the folder with `python3 -m http.server 8765`, launch the old app, and watch it download and install the new one on quit.

## Writing for users

Everything users read (the site, the README, release notes in `CHANGELOG.md`, the GitHub release, the app's own strings) leads with the problem it solves, not the feature's name. "Never miss a meeting again", not "a menu bar calendar"; "In the call in one click", not "Join button". Name the feature after the benefit, in plain words, then say how it works in one short sentence. English and Spanish say the same thing.

