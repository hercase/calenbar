import CalenbarCore
import SwiftUI

/// The gentle alert: a card the size of a notification in the corner of the screen, with the same
/// facts and buttons as the full-screen one, that stays until acted on or until the meeting ends.
struct AlertCardView: View {
    let model: AppModel
    let event: CalendarEvent
    let actions: AlertActions

    var body: some View {
        let now = model.now
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                Text(AlertFacts.headline(event: event, now: now))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AlertFacts.headlineTint(event: event, now: now))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                IconButton(
                    systemImage: "calendar", label: String(localized: "Open in \(model.eventDestinationName(event))"),
                    action: actions.openEvent)
                if let link = event.meetingLink {
                    IconButton(
                        systemImage: "link", label: String(localized: "Copy meeting link"),
                        action: { actions.copyLink(link) })
                }
                IconButton(systemImage: "xmark.circle.fill", label: String(localized: "Dismiss"), action: actions.dismiss)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(TitleFormatter.displayTitle(event))
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: event.calendarColorHex)).frame(width: 7, height: 7)
                    Text(verbatim: "\(EventTimeText.range(event)) · \(event.calendarTitle)")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let place = AlertFacts.place(event) {
                    Label(place, systemImage: event.rooms.isEmpty ? "mappin.and.ellipse" : "door.left.hand.open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let people = AlertFacts.people(event) {
                    Label(people, systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 8) {
                if let link = event.meetingLink {
                    Button {
                        actions.join(link)
                    } label: {
                        // Long translations ("Unirse a Google Meet") plus the key don't fit the card:
                        // then just "Join", since the logo already says which service.
                        ViewThatFits(in: .horizontal) {
                            joinLabel(link, text: Text("Join \(link.provider.displayName)"))
                            joinLabel(link, text: Text("Join"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.borderedProminent)
                    .pointingHandCursor()
                }
                SnoozeMenu(event: event, now: now, snooze: actions.snooze)
                    .fixedSize()
            }
            .controlSize(.large)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        .onExitCommand(perform: actions.dismiss)  // Esc, once the card has focus.
        .padding(10)  // Room for the window's shadow.
    }

    private func joinLabel(_ link: MeetingLink, text: Text) -> some View {
        HStack(spacing: 6) {
            ProviderChipView(provider: link.provider, size: 12)
            text.lineLimit(1)
            if let shortcut = model.settings.joinShortcut {
                KeyCap(text: shortcut.display)
            }
        }
    }
}
