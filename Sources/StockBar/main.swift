import Cocoa

// StockBar is a menu-bar-only ("accessory") app. The activation policy is set
// here as a backup; LSUIElement in Info.plist is what hides it from the Dock
// when running as a bundled .app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
