import Foundation
import Observation

/// UI state for the panel. Kept in an `@Observable` class instead of SwiftUI `@State` because the
/// Command Line Tools toolchain doesn't ship the SwiftUI macro plugin that `@State` needs.
@MainActor
@Observable
final class PanelState {
    var selectedDay = Calendar.current.startOfDay(for: Date())
    var displayedMonth = Calendar.current.startOfMonth(for: Date())

    /// Row under the mouse; reveals its inline actions.
    var hoveredEventID: String?
    /// Row whose detail card is showing; set after a short hover so skimming the list doesn't flash cards.
    var detailEventID: String?
    @ObservationIgnored private var isHoveringDetail = false
    @ObservationIgnored private var showTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?

    func resetToToday() {
        selectedDay = Calendar.current.startOfDay(for: Date())
        displayedMonth = Calendar.current.startOfMonth(for: Date())
        hoveredEventID = nil
        detailEventID = nil
    }

    func setHovering(_ isHovering: Bool, eventID: String) {
        showTask?.cancel()
        if isHovering {
            closeTask?.cancel()
            hoveredEventID = eventID
            if detailEventID != nil {
                // A card is already open: follow the mouse without waiting again.
                detailEventID = eventID
                return
            }
            showTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, self?.hoveredEventID == eventID else { return }
                self?.detailEventID = eventID
            }
        } else if hoveredEventID == eventID {
            hoveredEventID = nil
            scheduleClose()
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
            guard let self, !Task.isCancelled, !self.isHoveringDetail, self.hoveredEventID == nil else { return }
            self.detailEventID = nil
        }
    }
}

/// UI state for the Settings window (see `PanelState` for why this isn't `@State`).
@MainActor
@Observable
final class SettingsUIState {
    var timeZoneQuery = ""
    var isAddingClock = false
}
