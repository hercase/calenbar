import CalenbarCore
import SwiftUI

/// "Copy link" that confirms itself for a moment, so the click doesn't feel like it did nothing.
struct CopyLinkButton: View {
    let link: MeetingLink
    let copy: (MeetingLink) -> Void
    @StateObject private var flash = CopiedFlash()

    var body: some View {
        let copied = flash.isOn
        Button {
            copy(link)
            flash.trigger()
        } label: {
            Label(
                copied ? String(localized: "Copied") : String(localized: "Copy link"),
                systemImage: copied ? "checkmark" : "link"
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(String(localized: "Copy meeting link"))
    }
}

/// A switch that turns itself off again; `@StateObject` because `@State` needs the macro plugin the Command Line Tools lack.
@MainActor
private final class CopiedFlash: ObservableObject {
    @Published var isOn = false

    func trigger() {
        isOn = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            isOn = false
        }
    }
}

/// Snooze choices shared by both alert styles.
struct SnoozeMenu: View {
    let event: CalendarEvent
    let now: Date
    let snooze: (Date) -> Void

    var body: some View {
        Menu("Snooze") {
            if event.start.timeIntervalSince(now) > 60 {
                Button("When it starts") { snooze(event.start) }
            }
            ForEach(AlertTiming.snoozeMinutes, id: \.self) { minutes in
                Button("\(minutes) min") { snooze(Date().addingTimeInterval(TimeInterval(minutes * 60))) }
            }
        }
        .pointingHandCursor()
    }
}

/// The lines both alert styles print about the meeting.
enum AlertFacts {
    /// Rooms first (they're what you walk to); otherwise the free-text location when it says something.
    static func place(_ event: CalendarEvent) -> String? {
        event.rooms.isEmpty ? event.displayLocation : event.rooms.joined(separator: ", ")
    }

    /// "Organized by Ana · 6 guests · 4 accepted"; nothing for an event with no other guests.
    static func people(_ event: CalendarEvent) -> String? {
        let others = event.people.filter { !$0.isCurrentUser }
        guard !others.isEmpty else { return nil }
        let accepted = event.people.filter { $0.status == .accepted }.count
        let counts = String(localized: "\(event.people.count) guests · \(accepted) accepted")
        if let organizer = event.organizer, !organizer.isCurrentUser {
            return String(localized: "Organized by \(organizer.displayName)") + " · " + counts
        }
        return counts
    }

    /// Quiet before the start, accent as it starts, orange once you're late. Text says the same thing,
    /// so colour is only reinforcement.
    static func headlineTint(event: CalendarEvent, now: Date) -> Color {
        if event.start > now { return .secondary }
        return RelativeTime.minutesSince(event.start, now: now) == 0 ? .accentColor : .orange
    }

    /// Live: "Starting in 2m", then "Starting now" for the first minute, then "Started 3m ago".
    static func headline(event: CalendarEvent, now: Date) -> String {
        if event.start > now {
            return String(localized: "Starting in \(RelativeTime.until(event.start, now: now))")
        }
        if RelativeTime.minutesSince(event.start, now: now) == 0 {
            return String(localized: "Starting now")
        }
        return String(localized: "Started \(RelativeTime.since(event.start, now: now)) ago")
    }
}

/// The key that triggers a button, printed the way menus print theirs: macOS glyphs in dimmed type,
/// no box, set apart from the label. Glyphs where macOS has a readable one (↩), "esc" where it does not (⎋).
struct KeyCap: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .opacity(0.55)
            .padding(.leading, 10)
            .accessibilityHidden(true)
    }
}
