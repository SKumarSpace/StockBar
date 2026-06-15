import Foundation

/// A single point-in-time quote for a symbol.
struct Quote {
    let symbol: String
    let price: Double
    let previousClose: Double
    let currency: String
    let marketState: String   // PRE | REGULAR | POST | CLOSED | (others)

    var change: Double { price - previousClose }
    var changePercent: Double { previousClose == 0 ? 0 : (change / previousClose) * 100 }

    /// True only during regular trading hours, per Yahoo's own market state.
    var isOpen: Bool { marketState == "REGULAR" }
}

enum FinanceError: Error {
    case badResponse(Int)
    case noData
}

final class FinanceClient {

    /// Cheap local check used to avoid pointless network calls when the US
    /// market is clearly closed (nights / weekends). Correctness for the
    /// "is it open?" label still comes from `Quote.marketState`, which also
    /// accounts for holidays. NY timezone handles DST automatically.
    func isLikelyMarketOpen(now: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let c = cal.dateComponents([.weekday, .hour, .minute], from: now)
        // weekday: 1 = Sunday ... 7 = Saturday. Monday...Friday == 2...6.
        guard let wd = c.weekday, (2...6).contains(wd) else { return false }
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return minutes >= (9 * 60 + 30) && minutes < (16 * 60)
    }

    func fetchQuote(symbol: String) async throws -> Quote {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)")!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        // Yahoo's endpoint rejects requests without a browser-like User-Agent.
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FinanceError.badResponse(-1) }
        guard http.statusCode == 200 else { throw FinanceError.badResponse(http.statusCode) }

        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let meta = decoded.chart.result?.first?.meta else { throw FinanceError.noData }

        return Quote(
            symbol: meta.symbol ?? symbol,
            price: meta.regularMarketPrice ?? 0,
            previousClose: meta.chartPreviousClose ?? meta.previousClose ?? 0,
            currency: meta.currency ?? "USD",
            marketState: meta.marketState ?? "CLOSED"
        )
    }
}

// MARK: - Yahoo chart response (only the fields we use)

private struct ChartResponse: Decodable {
    struct Chart: Decodable { let result: [Result]? }
    struct Result: Decodable { let meta: Meta }
    struct Meta: Decodable {
        let symbol: String?
        let currency: String?
        let regularMarketPrice: Double?
        let chartPreviousClose: Double?
        let previousClose: Double?
        let marketState: String?
    }
    let chart: Chart
}
