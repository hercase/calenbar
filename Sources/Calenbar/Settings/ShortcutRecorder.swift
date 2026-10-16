import AppKit
import Carbon.HIToolbox
import SwiftUI

/// "Record Shortcut": click, press a combination, done. Esc cancels, ⌫ removes the current one.
struct ShortcutRecorder: View {
    @Bindable var settings: AppSettings
    @Bindable var uiState: SettingsUIState

    var body: some View {
        HStack(spacing: PanelStyle.small) {
            Button {
                uiState.isRecordingShortcut ? stopRecording() : startRecording()
            } label: {
                Text(label)
                    .frame(minWidth: 110)
                    .monospacedDigit()
            }
            .help(
                uiState.isRecordingShortcut ? String(localized: "Esc cancels") : String(localized: "Click, then press the keys"))
            if settings.joinShortcut != nil, !uiState.isRecordingShortcut {
                IconButton(systemImage: "xmark.circle.fill", label: String(localized: "Remove shortcut")) {
                    settings.joinShortcut = nil
                }
            }
        }
    }

    private var label: String {
        if uiState.isRecordingShortcut {
            return String(localized: "Press keys…")
        }
        return settings.joinShortcut?.display ?? String(localized: "Record Shortcut")
    }

    private func startRecording() {
        uiState.isRecordingShortcut = true
        uiState.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                switch Int(event.keyCode) {
                case kVK_Escape:
                    stopRecording()
                case kVK_Delete:
                    settings.joinShortcut = nil
                    stopRecording()
                default:
                    // A key without ⌘, ⌃ or ⌥ isn't a shortcut; keep waiting.
                    if let shortcut = KeyShortcut(event: event) {
                        settings.joinShortcut = shortcut
                        stopRecording()
                    }
                }
            }
            // Swallowed either way: nothing typed while recording should reach the window.
            return nil
        }
    }

    private func stopRecording() {
        if let monitor = uiState.keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        uiState.keyMonitor = nil
        uiState.isRecordingShortcut = false
    }
}
