import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let finance = FinanceClient()
    private var lastQuote: Quote?

    private let refreshInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "…"
        rebuildMenu()
        refresh()
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    // MARK: - Data

    private func refresh() {
        let symbol = Settings.ticker

        // If the market is clearly closed and we already have a value, just
        // re-render it as "closed" without hitting the network.
        if !finance.isLikelyMarketOpen(), let quote = lastQuote {
            render(quote: quote, closed: true)
            return
        }

        Task {
            do {
                let quote = try await finance.fetchQuote(symbol: symbol)
                await MainActor.run {
                    self.lastQuote = quote
                    // Yahoo's chart endpoint often omits `marketState`, so trust
                    // the local NY-trading-hours check for the open/closed label.
                    self.render(quote: quote, closed: !self.finance.isLikelyMarketOpen())
                }
            } catch {
                await MainActor.run {
                    self.statusItem.button?.title = "\(symbol) —"
                }
            }
        }
    }

    // MARK: - Rendering

    private func render(quote: Quote, closed: Bool) {
        let arrow = quote.change > 0 ? "▲" : (quote.change < 0 ? "▼" : "▬")
        let priceText = String(format: "%@ %@ %.2f", quote.symbol, arrow, quote.price)

        let color: NSColor = quote.change > 0 ? .systemGreen
            : (quote.change < 0 ? .systemRed : .labelColor)
        let attributed = NSAttributedString(
            string: priceText,
            attributes: [
                .foregroundColor: closed ? NSColor.secondaryLabelColor : color,
                .font: NSFont.menuBarFont(ofSize: 0)
            ]
        )
        statusItem.button?.attributedTitle = attributed

        rebuildMenu(closed: closed)
    }

    private func rebuildMenu(closed: Bool = false) {
        let menu = NSMenu()

        if let q = lastQuote {
            let header = NSMenuItem(
                title: String(format: "%@  %.2f %@", q.symbol, q.price, q.currency),
                action: nil, keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)

            let detail = NSMenuItem(
                title: String(format: "%+.2f (%+.2f%%) · prev %.2f", q.change, q.changePercent, q.previousClose),
                action: nil, keyEquivalent: ""
            )
            detail.isEnabled = false
            menu.addItem(detail)

            let state = NSMenuItem(
                title: closed ? "Market: closed" : "Market: open",
                action: nil, keyEquivalent: ""
            )
            state.isEnabled = false
            menu.addItem(state)
        } else {
            let loading = NSMenuItem(title: "Loading…", action: nil, keyEquivalent: "")
            loading.isEnabled = false
            menu.addItem(loading)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Set Ticker…", action: #selector(setTicker), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))

        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit StockBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Targets default to nil (first responder); set explicitly for our actions.
        for item in menu.items where item.action != nil && item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func setTicker() {
        guard let new = Settings.promptForTicker(current: Settings.ticker) else { return }
        Settings.ticker = new
        lastQuote = nil
        statusItem.button?.title = "…"
        refresh()
    }

    @objc private func refreshNow() {
        refresh()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
        rebuildMenu(closed: lastQuote.map { !$0.isOpen } ?? false)
    }
}
