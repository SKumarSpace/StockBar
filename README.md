<img src="docs/icon.png" alt="StockBar icon" width="120" align="left">

# StockBar

A tiny macOS **menu bar** app that shows a stock's price from Yahoo Finance.
No Dock icon, no windows — just the price in your menu bar. Updates every
minute while the US market is open, and goes quiet (showing the last close)
when it's closed.

<img src="docs/menu.png" alt="StockBar menu bar item with its menu open" width="310">

## Features

- Live price in the menu bar — green ▲ when up, red ▼ when down:

  <img src="docs/up.png" alt="NVDA up, shown in green" width="136">
  <img src="docs/down.png" alt="AAPL down, shown in red" width="133">

- Click for the day's change, percent, and previous close
- Refreshes every 60 seconds during market hours; skips updates when closed,
  and greys out the price to show it's a stale close
- Pick any symbol from the menu (**Set Ticker…**) — defaults to `MU`
- **Launch at Login** toggle
- Pure menu-bar agent (`LSUIElement`) — no Dock icon, no main window

## Install

### Download (recommended)

**[⬇ Download StockBar](https://github.com/SKumarSpace/StockBar/releases/latest/download/StockBar.zip)** — macOS 13+, Apple Silicon & Intel

1. Unzip and drag **StockBar.app** to `/Applications`.
2. Double-click to launch. The price appears in your menu bar.

That's it — no security warnings. Releases are signed with a Developer ID
certificate and notarized by Apple, so Gatekeeper opens them normally.

### Build from source

Requires the Xcode command line tools (`xcode-select --install`) or Xcode.

```sh
git clone https://github.com/SKumarSpace/StockBar.git
cd StockBar
swift run                 # run directly for development
./Scripts/build-app.sh    # produce dist/StockBar.app + dist/StockBar.zip
```

A build from source is only ad-hoc signed, not notarized — so macOS will warn
on first launch. Right-click the app → **Open** → **Open**, or run
`xattr -dr com.apple.quarantine /Applications/StockBar.app`.

## Distribution (signing & notarization)

For a download that opens with no Gatekeeper warning, you need an Apple
Developer account ($99/yr) and a **Developer ID Application** certificate.

Local build:

```sh
# one-time: store an app-specific password for the notary service
xcrun notarytool store-credentials "stockbar" \
  --apple-id "you@example.com" --team-id "TEAMID" \
  --password "app-specific-password"

SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="stockbar" \
  ./Scripts/build-app.sh
```

Automated release: push a tag (`git tag v1.0.0 && git push --tags`) and the
GitHub Actions workflow builds, signs, notarizes, and attaches `StockBar.zip`
to a GitHub Release. Set these repository **secrets**:

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12` | base64 of your exported Developer ID `.p12` |
| `MACOS_CERT_PASSWORD` | password for that `.p12` |
| `KEYCHAIN_PASSWORD` | any string; temporary CI keychain password |
| `SIGN_ID` | `Developer ID Application: Your Name (TEAMID)` |
| `NOTARY_APPLE_ID` | your Apple ID email |
| `NOTARY_TEAM_ID` | your 10-char Team ID |
| `NOTARY_PASSWORD` | an app-specific password |

### Linking from a website

This URL always resolves to the newest release's asset, so it never needs
updating when you cut a new version:

```
https://github.com/SKumarSpace/StockBar/releases/latest/download/StockBar.zip
```

Notarization tickets are **stapled** into the app, so it opens cleanly even if
the user is offline — the download can be hosted anywhere (your own site, a
CDN), not just GitHub.

## How it works

- Price data: Yahoo's chart endpoint
  `https://query1.finance.yahoo.com/v8/finance/chart/<SYMBOL>` (no API key).
- Open/closed: uses the response's `marketState` (which also covers holidays),
  plus a local New-York-hours check to avoid needless network calls overnight.
- Built with SwiftPM; `Scripts/build-app.sh` wraps the binary into a `.app`
  bundle with `Info.plist` (`LSUIElement = true`).

## Disclaimer

Data comes from an unofficial Yahoo Finance endpoint and may be delayed or
break without notice. For informational use only — not financial advice.

## License

MIT — see [LICENSE](LICENSE).
