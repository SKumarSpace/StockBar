import Cocoa

/// Persisted preferences. The chosen ticker lives in UserDefaults so it
/// survives relaunches.
enum Settings {
    private static let tickerKey = "ticker"

    static var ticker: String {
        get { UserDefaults.standard.string(forKey: tickerKey) ?? "MU" }
        set { UserDefaults.standard.set(newValue.uppercased(), forKey: tickerKey) }
    }

    /// Modal prompt for a new symbol. Returns the upper-cased value, or nil if
    /// the user cancelled or left it empty.
    static func promptForTicker(current: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Set Ticker Symbol"
        alert.informativeText = "Enter a stock symbol (e.g. MU, AAPL, NVDA)."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = current
        alert.accessoryView = field

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }

        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value.uppercased()
    }
}
