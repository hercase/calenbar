import CalenbarCore
import Foundation
import Observation

/// UI state for the panel. Kept in an `@Observable` class instead of SwiftUI `@State` because the
/// Command Line Tools toolchain doesn't ship the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class PanelState {
    /// How long the pointer rests on a row before its card opens. Long enough that sweeping across the
    /// list on the way somewhere else opens nothing.
    static let detailDelay: Duration = .milliseconds(700)
    /// With a card already open, the next row still has to be meant: passing over three rows on the way
    /// to a fourth shouldn't flash three cards.
    static let detailSwitchDelay: Duration = .milliseconds(250)
    /// The gap's actions push the rows below it down, so they wait until the pointer has clearly stopped.
    static let freeRevealDelay: Duration = .milliseconds(550)

    var selectedDay = Calendar.current.startOfDay(for: Date())
    var displayedMonth = Calendar.current.startOfMonth(for: Date())
    /// Pinned: the panel stays open when you click elsewhere, until the menu bar item is clicked again.
    var isPanelPinned = false

    /// Row under the mouse; reveals its inline actions.
    var hoveredEventID: String?
    /// Free-time row under the mouse. The label is always visible; the actions wait a beat.
    var hoveredFreeID: String?
    /// Free-time row whose Focus / Lunch / Meeting actions are showing.
    var revealedFreeID: String?
    /// Where the shared block starts inside a gap. Absent means the beginning of the bookable stretch.
    var blockStarts: [String: Date] = [:]
    /// How long that block is. Absent means the length chosen in Settings.
    var blockLengths: [String: FreeTime.BlockLength] = [:]
    /// Row whose detail card is showing; set after a short hover so skimming the list doesn't flash cards.
    var detailEventID: String?
    /// A clicked row keeps its card open until it is clicked again, another row is clicked, or the card is dismissed.
    @ObservationIgnored private var isPinned = false
    @ObservationIgnored private var isHoveringDetail = false
    @ObservationIgnored private var showTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    /// Set by a click or the keyboard, so the actions survive until the pointer actually leaves.
    @ObservationIgnored private var pinnedFreeID: String?
    @ObservationIgnored private var freeRevealTask: Task<Void, Never>?

    func resetToToday() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        displayedMonth = Calendar.current.startOfMonth(for: Date())
        hoveredEventID = nil
        detailEventID = nil
        isPinned = false
        hoveredFreeID = nil
        revealedFreeID = nil
        pinnedFreeID = nil
        blockStarts = [:]
        blockLengths = [:]
        freeRevealTask?.cancel()
    }

    /// Click or Return on a row: show its card right away and keep it open; a second click lets it go.
    func toggleDetail(eventID: String) {
        showTask?.cancel()
        closeTask?.cancel()
        if isPinned, detailEventID == eventID {
            isPinned = false
            detailEventID = nil
        } else {
            isPinned = true
            detailEventID = eventID
        }
    }

    /// The card was dismissed by the system (Esc, click outside).
    func detailDismissed(eventID: String) {
        guard detailEventID == eventID else { return }
        detailEventID = nil
        isPinned = false
    }

    func setHovering(_ isHovering: Bool, eventID: String) {
        showTask?.cancel()
        if isHovering {
            closeTask?.cancel()
            hoveredEventID = eventID
            if isPinned {
                return
            }
            if detailEventID == eventID { return }
            let delay = detailEventID == nil ? Self.detailDelay : Self.detailSwitchDelay
            showTask = Task { [weak self] in
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, self?.hoveredEventID == eventID else { return }
                self?.detailEventID = eventID
            }
        } else if hoveredEventID == eventID {
            hoveredEventID = nil
            scheduleClose()
        }
    }

    /// Highlight the gap immediately. The actions follow after a short beat so skimming the list
    /// doesn't flash them; a click or Return shows them at once.
    func setHoveringFree(_ isHovering: Bool, id: String) {
        freeRevealTask?.cancel()
        if isHovering {
            hoveredFreeID = id
            if pinnedFreeID == id {
                revealedFreeID = id
                return
            }
            freeRevealTask = Task { [weak self] in
                try? await Task.sleep(for: Self.freeRevealDelay)
                guard !Task.isCancelled, self?.hoveredFreeID == id else { return }
                self?.revealedFreeID = id
            }
        } else if hoveredFreeID == id {
            hoveredFreeID = nil
            pinnedFreeID = nil
            revealedFreeID = nil
        }
    }

    /// The interval every chip will use. `defaultLength` is the Settings value, until this gap picks its own.
    func placement(for slot: FreeTime.Slot, defaultLength: TimeInterval) -> FreeTime.Placement {
        FreeTime.placement(
            in: slot, preferredStart: blockStarts[slot.id], length: blockLengths[slot.id] ?? .fixed(defaultLength))
    }

    func shiftBlock(_ slot: FreeTime.Slot, forward: Bool, defaultLength: TimeInterval) {
        let current = placement(for: slot, defaultLength: defaultLength)
        let start = FreeTime.shiftedStart(in: slot, from: current.interval.start, length: current.length, forward: forward)
        guard start != current.interval.start else { return }
        blockStarts[slot.id] = start
        blockLengths[slot.id] = current.length
    }

    func chooseLength(_ slot: FreeTime.Slot, _ length: FreeTime.BlockLength, defaultLength: TimeInterval) {
        blockLengths[slot.id] = length
        blockStarts[slot.id] = placement(for: slot, defaultLength: defaultLength).interval.start
    }

    func toggleFree(_ id: String) {
        freeRevealTask?.cancel()
        if pinnedFreeID == id {
            pinnedFreeID = nil
            revealedFreeID = hoveredFreeID == id ? id : nil
        } else {
            pinnedFreeID = id
            revealedFreeID = id
        }
    }

    /// Keeps the card open while the mouse is on it, so its Join button and text can be used.
    func setHoveringDetail(_ isHovering: Bool) {
        isHoveringDetail = isHovering
        if isHovering {
            closeTask?.cancel()
        } else {
            scheduleClose()
        }
    }

    /// Grace period to travel from the row to the card without it closing.
    private func scheduleClose() {
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, !Task.isCancelled, !self.isPinned, !self.isHoveringDetail, self.hoveredEventID == nil else { return }
            self.detailEventID = nil
        }
    }
}

/// UI state for the Settings window (see `PanelState` for why this isn't `@State`).
@MainActor
@Observable
final class SettingsUIState {
    var isAddingClock = false
    /// Feedback under the clock list after a pick that changed nothing.
    var clockNote: String?
    let citySearch = CitySearch()
    var isRecordingShortcut = false
    /// The key monitor installed while recording, so it can be removed.
    @ObservationIgnored var keyMonitor: Any?
}
