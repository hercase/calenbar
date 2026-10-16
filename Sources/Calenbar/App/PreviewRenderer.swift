import AppKit
import CalenbarCore
import SwiftUI

/// Renders every surface to PNG files from fixture data, so visual changes can be checked without
/// a running UI: `Calenbar --render-previews <directory>` (see scripts/previews.sh).
@MainActor
enum PreviewRenderer {
    static func outputDirectory(from arguments: [String]) -> URL? {
        guard let index = arguments.firstIndex(of: "--render-previews"), index + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }

    static func renderAll(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fixtures = PreviewFixtures()

        for (name, view) in panels(fixtures) {
            try write(view.frame(width: PanelStyle.width), named: name, in: directory)
        }
        fixtures.model.settings.showMonthCalendar = true
        fixtures.model.settings.showWeekNumbers = true
        try write(
            PanelView(model: fixtures.model, state: PanelState(), openSettings: {}).frame(width: PanelStyle.width),
            named: "panel-month", in: directory)
        try write(EventDetailView(model: fixtures.model, event: fixtures.meeting), named: "detail-card", in: directory)
        try write(
            AlertView(model: fixtures.model, event: fixtures.meeting, join: { _ in }, snooze: { _ in }, dismiss: {})
                .frame(width: 900, height: 420),
            named: "alert", in: directory)
        for page in SettingsWindow.pages(model: fixtures.model, uiState: SettingsUIState()) {
            try write(
                page.view.frame(width: SettingsWindow.pageSize.width, height: SettingsWindow.pageSize.height),
                named: "settings-\(page.title.lowercased().replacingOccurrences(of: " ", with: "-"))", in: directory)
        }
        try writeMenuBarStrip(fixtures, in: directory, named: "menu-bar.png")
        try writeMenuBarStrip(fixtures, in: directory, named: "menu-bar-update.png", updatePending: true)
        let shortcut = KeyShortcut.defaultJoin.display
        try write(
            MenuMockup(items: [
                .item("Restart to Update"), .separator, .item("Join Next Meeting", shortcut: shortcut), .separator,
                .item("Hide Event Titles"), .separator, .item("Open Calendar"), .item("Settings…", shortcut: "⌘,"), .separator,
                .item("Quit Calenbar", shortcut: "⌘Q"),
            ]), named: "menu-right-click", in: directory)
        try write(
            MenuMockup(items: [
                .item("Update to 0.5.0…"), .separator, .item("Join Next Meeting", shortcut: shortcut),
                .item("New Meeting", shortcut: "›"), .separator, .item("Hide Event Titles in Menu Bar", check: true), .separator,
                .item("Open Calendar"), .item("Settings…", shortcut: "⌘,"), .separator, .item("Quit Calenbar", shortcut: "⌘Q"),
            ]), named: "menu-more", in: directory)
    }

    private static func panels(_ fixtures: PreviewFixtures) -> [(String, AnyView)] {
        let state = PanelState()
        state.hoveredEventID = fixtures.oneOnOne.id
        return [
            ("panel", AnyView(PanelView(model: fixtures.model, state: state, openSettings: {}))),
            ("panel-done", AnyView(PanelView(model: fixtures.doneModel, state: PanelState(), openSettings: {}))),
            ("panel-no-calendars", AnyView(PanelView(model: fixtures.noCalendarsModel, state: PanelState(), openSettings: {}))),
            ("panel-no-account", AnyView(PanelView(model: fixtures.noAccountModel, state: PanelState(), openSettings: {}))),
            ("panel-access-needed", AnyView(PanelView(model: fixtures.accessNeededModel, state: PanelState(), openSettings: {}))),
        ]
    }

    /// Light and dark renderings side by side, at 2x.
    private static func write(_ view: some View, named name: String, in directory: URL) throws {
        let images = [NSAppearance.Name.aqua, .darkAqua].map { appearance in
            render(view.background(Color(nsColor: .windowBackgroundColor)), appearance: appearance)
        }
        let gap: CGFloat = 16
        let size = NSSize(width: images.map(\.size.width).reduce(0, +) + gap, height: images.map(\.size.height).max() ?? 0)
        let composite = NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for image in images {
                image.draw(
                    at: NSPoint(x: x, y: size.height - image.size.height), from: .zero, operation: .sourceOver, fraction: 1)
                x += image.size.width + gap
            }
            return true
        }
        try png(composite, scale: 2).write(to: directory.appending(path: "\(name).png"))
    }

    private static func render(_ view: some View, appearance: NSAppearance.Name) -> NSImage {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        // Views only lay out and resolve dynamic colors inside a window; it never needs to be shown.
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let image = NSImage(size: host.bounds.size)
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return image }
        host.cacheDisplay(in: host.bounds, to: rep)
        image.addRepresentation(rep)
        return image
    }

    private static func png(_ image: NSImage, scale: CGFloat) throws -> Data {
        let size = image.size
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { throw CocoaError(.fileWriteUnknown) }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return data
    }

    /// The date icon and a title the way the status item lays them out, beside system icons, in both appearances.
    private static func writeMenuBarStrip(
        _ fixtures: PreviewFixtures, in directory: URL, named name: String, updatePending: Bool = false
    ) throws {
        let font = NSFont.menuBarFont(ofSize: 0)
        let title = TitleFormatter.title(for: fixtures.meeting, now: fixtures.model.now)
        let day = Calendar.current.component(.day, from: fixtures.model.now)
        let rows: [(NSColor, NSColor)] = [(NSColor(white: 0.93, alpha: 1), .black), (NSColor(white: 0.16, alpha: 1), .white)]
        let size = NSSize(width: 420, height: 24 * CGFloat(rows.count))
        let image = NSImage(size: size, flipped: false) { _ in
            for (index, (background, tint)) in rows.enumerated() {
                let y = size.height - 24 * CGFloat(index + 1)
                background.setFill()
                NSRect(x: 0, y: y, width: size.width, height: 24).fill()
                var x: CGFloat = 12
                func place(_ icon: NSImage, gap: CGFloat = 8) {
                    let tinted = NSImage(size: icon.size, flipped: false) { rect in
                        icon.draw(in: rect)
                        tint.set()
                        rect.fill(using: .sourceAtop)
                        return true
                    }
                    tinted.draw(
                        at: NSPoint(x: x, y: y + (24 - icon.size.height) / 2), from: .zero, operation: .sourceOver, fraction: 1)
                    x += icon.size.width + gap
                }
                place(DateIcon.image(day: day, showsBadge: updatePending))
                (title as NSString).draw(at: NSPoint(x: x, y: y + 4), withAttributes: [.font: font, .foregroundColor: tint])
                x += (title as NSString).size(withAttributes: [.font: font]).width + 18
                for symbol in ["wifi", "battery.100", "calendar"] {
                    if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
                        place(icon, gap: 14)
                    }
                }
                place(DateIcon.image(day: 31))
            }
            return true
        }
        try png(image, scale: 4).write(to: directory.appending(path: name))
    }
}

/// A static picture of a menu's rows, for previews only: real menus can't be rendered off screen.
private struct MenuMockup: View {
    enum Row {
        case item(String, shortcut: String? = nil, check: Bool = false)
        case separator
    }

    let items: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, row in
                switch row {
                case .separator:
                    Divider().padding(.vertical, 5).padding(.horizontal, 10)
                case .item(let title, let shortcut, let check):
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").font(.caption.weight(.semibold)).opacity(check ? 1 : 0).frame(width: 12)
                        Text(verbatim: title)
                        Spacer(minLength: 24)
                        if let shortcut {
                            Text(verbatim: shortcut).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                }
            }
        }
        .font(.system(size: 13))
        .padding(.vertical, 5)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }
}

/// Made-up events around the current time, so previews always show a live-looking state.
@MainActor
struct PreviewFixtures {
    let meeting: CalendarEvent
    let oneOnOne: CalendarEvent
    let model: AppModel
    let doneModel: AppModel
    let noCalendarsModel: AppModel
    let noAccountModel: AppModel
    let accessNeededModel: AppModel

    init() {
        let now = Date()
        let people = Self.people()
        meeting = Self.event(
            "Weekly Sync", start: now.addingTimeInterval(12 * 60), minutes: 30, id: "sync",
            url: URL(string: "https://meet.google.com/abc-defg-hij"), attendees: people + [Self.room], status: .accepted,
            notes: "Agenda\n• Roadmap for Q4\n• Hiring update")
        oneOnOne = Self.event(
            "1:1 with Ana", start: now.addingTimeInterval(150 * 60), minutes: 30, id: "one",
            url: URL(string: "https://zoom.us/j/123456"), attendees: Array(people.prefix(2)), status: .pending)
        let past = Self.event(
            "Design review", start: now.addingTimeInterval(-120 * 60), minutes: 60, id: "past",
            attendees: Array(people.prefix(2)),
            status: .accepted)
        let gym = Self.event("Gym", start: Self.at(19, 0), minutes: 60, id: "gym", calendar: ("personal", "#34C759"))
        let offsite = Self.event(
            "Company offsite", start: Self.at(0, 0, dayOffset: 1), minutes: 24 * 60, id: "offsite", isAllDay: true)
        let vacation = Self.event(
            "Out of office", start: Self.at(0, 0, dayOffset: 3), minutes: 2 * 24 * 60, id: "ooo", isAllDay: true)
        let planning = Self.event(
            "Sprint planning", start: Self.at(10, 0, dayOffset: 1), minutes: 60, id: "planning",
            url: URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0"),
            attendees: Array(people.prefix(2)), status: .accepted)
        let calendars = [
            CalendarInfo(id: "work", title: "me@example.com", colorHex: "#3B82F6", sourceTitle: "Google", isFromAccount: true),
            CalendarInfo(id: "personal", title: "Personal", colorHex: "#34C759", sourceTitle: "iCloud", isFromAccount: true),
        ]
        let localOnly = [
            CalendarInfo(id: "home", title: "Home", colorHex: "#3B82F6", sourceTitle: "On My Mac", isFromAccount: false),
            CalendarInfo(id: "birthdays", title: "Birthdays", colorHex: "#8E8E93", sourceTitle: "Other", isFromAccount: false),
        ]
        model = Self.model(events: [past, meeting, oneOnOne, gym, offsite, planning, vacation], calendars: calendars)
        doneModel = Self.model(events: [past, offsite, planning], calendars: calendars)
        noCalendarsModel = Self.model(events: [], calendars: [])
        noAccountModel = Self.model(events: [], calendars: localOnly)
        accessNeededModel = Self.model(events: [], calendars: [], access: .notDetermined)
    }

    private static let room = Attendee(
        name: "BA-4-Lobby (8)", email: nil, status: .accepted, kind: .room, isCurrentUser: false, isOrganizer: false)

    /// Organizer, the current user, and one guest who hasn't answered.
    private static func people() -> [Attendee] {
        [
            Attendee(
                name: "Ana Pérez", email: "ana@example.com", status: .accepted, kind: .person, isCurrentUser: false,
                isOrganizer: true),
            Attendee(
                name: "Hernan", email: "me@example.com", status: .accepted, kind: .person, isCurrentUser: true, isOrganizer: false
            ),
            Attendee(
                name: "Tomás López", email: "tomas@example.com", status: .pending, kind: .person, isCurrentUser: false,
                isOrganizer: false),
        ]
    }

    private static func at(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func event(
        _ title: String,
        start: Date,
        minutes: Int,
        id: String,
        calendar: (String, String) = ("work", "#3B82F6"),
        url: URL? = nil,
        attendees: [Attendee] = [],
        status: ParticipationStatus = .unknown,
        isAllDay: Bool = false,
        notes: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, externalID: id, title: title, start: start, end: start.addingTimeInterval(Double(minutes) * 60),
            isAllDay: isAllDay, calendarID: calendar.0, calendarTitle: calendar.0 == "work" ? "me@example.com" : "Personal",
            calendarColorHex: calendar.1, isDeclined: false, hasOtherAttendees: !attendees.isEmpty, url: url,
            location: nil, notes: notes, attendees: attendees, myStatus: status)
    }

    private static func model(
        events: [CalendarEvent],
        calendars: [CalendarInfo],
        access: CalendarService.Access = .granted
    ) -> AppModel {
        let suite = "com.hernancase.calenbar.previews"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(defaults: defaults)
        settings.worldClocks = [
            WorldClock(timeZoneID: "Europe/Madrid", name: "Madrid"), WorldClock(timeZoneID: "Asia/Tokyo", name: "Tokyo"),
        ]
        return AppModel(
            settings: settings, calendar: CalendarService(fixture: events, calendars: calendars, access: access),
            clock: MinuteClock())
    }
}
