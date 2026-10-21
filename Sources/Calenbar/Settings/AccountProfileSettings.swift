import CalenbarCore
import SwiftUI

/// Which browser profile each calendar account's meetings open in. Shown for browsers that can be
/// told; for the rest, a line saying meetings still open with the invited account.
struct AccountProfileSettings: View {
    @Bindable var settings: AppSettings
    let calendar: CalendarService

    var body: some View {
        if let browser = MeetingOpener.meetingBrowser(), !accounts.isEmpty {
            let listing = BrowserProfileReader.listing(for: browser.id)
            Section {
                if case .profiles(let profiles) = listing {
                    ForEach(accounts) { account in
                        picker(for: account, browser: browser, profiles: profiles)
                    }
                }
            } header: {
                Text("Open each meeting with its account")
            } footer: {
                SettingsFooter { footer(for: listing, browser: browser) }
            }
        }
    }

    private struct Account: Identifiable {
        let id: String
        let title: String
        let email: EmailAddress?
    }

    /// One row per signed-in account, however many calendars it has.
    private var accounts: [Account] {
        var seen: Set<String> = []
        return calendar.calendars
            .filter { $0.isFromAccount && !$0.sourceID.isEmpty }
            .compactMap { info -> Account? in
                guard seen.insert(info.sourceID).inserted else { return nil }
                return Account(id: info.sourceID, title: info.sourceTitle, email: EmailAddress(info.sourceTitle))
            }
    }

    private func picker(for account: Account, browser: MeetingOpener.Browser, profiles: [BrowserProfile]) -> some View {
        let isChromium = BrowserFamily.of(bundleID: browser.id)?.engine == .chromium
        let matched = account.email.flatMap { ProfileMatcher.profile(for: $0, in: profiles) }
        return Picker(selection: selection(for: account, browser: browser, profiles: profiles)) {
            if isChromium {
                if let matched {
                    Text("Automatic (\(matched.name))").tag(ProfileChoice.automatic)
                } else {
                    Text("Automatic").tag(ProfileChoice.automatic)
                }
                Text("Whichever window is in front").tag(ProfileChoice.none)
            } else {
                Text("Whichever window is in front").tag(ProfileChoice.automatic)
            }
            Divider()
            ForEach(profiles) { profile in
                Text(verbatim: profile.email.map { "\(profile.name) · \($0)" } ?? profile.name)
                    .tag(ProfileChoice.profile(bundleID: browser.id, id: profile.id))
            }
        } label: {
            Text(verbatim: account.title)
        }
    }

    /// A choice for another browser, or for a profile that's gone, shows (and acts) as automatic.
    private func selection(
        for account: Account, browser: MeetingOpener.Browser, profiles: [BrowserProfile]
    ) -> Binding<ProfileChoice> {
        Binding(
            get: {
                let choice = settings.profileChoice(forAccount: account.id)
                guard case .profile(let bundleID, let id) = choice else { return choice }
                let isAvailable =
                    bundleID.lowercased() == browser.id.lowercased() && profiles.contains { $0.id == id }
                return isAvailable ? choice : .automatic
            },
            set: { settings.setProfileChoice($0, forAccount: account.id) }
        )
    }

    @ViewBuilder
    private func footer(for listing: BrowserProfileReader.Listing, browser: MeetingOpener.Browser) -> some View {
        switch listing {
        case .profiles:
            Text("settings.accounts.footer")
        case .unreadable:
            Text("Couldn't read \(browser.name)'s profiles. Google Meet still opens with the invited account.")
        case .unsupported:
            Text("\(browser.name) can't be told which profile to use. Google Meet still opens with the invited account.")
        }
    }
}
