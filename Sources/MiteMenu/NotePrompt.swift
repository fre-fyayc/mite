import AppKit

enum NotePrompt {
    /// Returns the trimmed note, or nil when the user cancels. An empty string starts a timer with no note.
    static func ask(title: String) -> String? {
        activateApp()
        let alert = NSAlert()
        alert.messageText = title.isEmpty ? "Start timer" : title
        alert.informativeText = "Ticket or note. Leave this empty to start without one."
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = "Ticket or note"
        alert.accessoryView = field
        alert.window.level = .floating
        alert.window.initialFirstResponder = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

func formatElapsed(since: Date, now: Date = Date()) -> String {
    formatDuration(now.timeIntervalSince(since))
}

func formatDuration(_ interval: TimeInterval) -> String {
    let seconds = max(0, Int(interval))
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainder = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
    return String(format: "%d:%02d", minutes, remainder)
}
