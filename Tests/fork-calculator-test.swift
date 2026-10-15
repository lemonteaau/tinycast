// The fork's connector-free currency conversion, kept out of calc-test so that file stays upstream's.
import Foundation

@main
@MainActor
struct ForkCalculatorTests {
    static var failures = 0
    static var passes = 0

    static func main() {
        expectDisplay("610 aud cny", "2,867.00 CNY")
        expectDisplay("610 AUD CNY", "2,867.00 CNY")
        expectExpression("610 aud cny", "610 AUD")
        expectCopy("610 aud cny", "2867.00 CNY")
        expectDisplay("10usd cad", "13.60 CAD")
        expectDisplay("$10 cad", "13.60 CAD")
        expectDisplay("2*5 usd cad", "13.60 CAD")
        expectDisplay("10 pounds euros", "11.65 EUR")
        expectDisplay("1k usd eur", "920.00 EUR")
        expectDisplay("10 usd cad +", "13.60 CAD")
        expectError("5 usd npr", "No exchange rate for NPR.")
        expectError(
            "610 aud cny", "Exchange rates unavailable — check your connection.", rates: nil)
        expectNil("usd cad")
        expectNil("10 usd kg")
        expectNil("10 kg usd")
        expectNil("10 usd nonsense")
        expectNil("10 usd cad eur")
        // The explicit connectors keep their meaning beside the shorthand.
        expectDisplay("610 aud to cny", "2,867.00 CNY")
        expectDisplay("10 usd in cad", "13.60 CAD")
        // A preferred currency answers a bare amount ahead of the region's own.
        expectDisplay("100 aud", "470.00 CNY", region: "AUD", preferred: "CNY")
        expectDisplay("1 usd", "7.05 CNY", region: "AUD", preferred: "CNY")
        expectDisplay("$10 +", "10.00 USD", region: "AUD", preferred: "CNY")
        expectDisplay("1 usd to eur", "0.92 EUR", region: "AUD", preferred: "CNY")
        expectDisplay("705 cny", "150.00 AUD", region: "AUD", preferred: "CNY")
        expectDisplay("705 cny", "100.00 USD", region: "CNY", preferred: "CNY")
        expectDisplay("705 cny", "705.00 CNY", preferred: "CNY")
        expectDisplay("1 usd", "1.50 AUD", region: "AUD")
        expectDisplay("1 usd", "1.50 AUD", region: "AUD", preferred: "ZZZ")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static let now = Date(timeIntervalSince1970: 1_785_000_000)

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// NPR is absent on purpose: a recognized code must reach "no exchange rate", not no card.
    static let fx = CurrencyRates(
        base: "USD",
        rates: ["USD": 1, "EUR": 0.92, "GBP": 0.79, "CAD": 1.36, "AUD": 1.5, "CNY": 7.05],
        fetchedAt: now)

    static func evaluate(
        _ query: String, rates: CurrencyRates? = fx, region: String? = nil, preferred: String? = nil
    ) -> CalcResult? {
        CalcEngine.evaluate(
            query, now: now, calendar: calendar, rates: rates, region: region, preferred: preferred)
    }

    static func check(_ query: String, expected: String, got: String) {
        if got == expected {
            passes += 1
        } else {
            failures += 1
            print("FAIL  \(query)\n      expected: \(expected)\n      got:      \(got)")
        }
    }

    static func expectDisplay(
        _ query: String, _ expected: String, region: String? = nil, preferred: String? = nil
    ) {
        let label = [query, region.map { "region \($0)" }, preferred.map { "preferred \($0)" }]
            .compactMap { $0 }.joined(separator: " · ")
        let result = evaluate(query, region: region, preferred: preferred)
        guard case .value(let display, _)? = result?.payload else {
            check(label, expected: expected, got: "nil / error")
            return
        }
        check(label, expected: expected, got: display)
    }

    static func expectCopy(_ query: String, _ expected: String) {
        guard case .value(_, let copy)? = evaluate(query)?.payload else {
            check(query, expected: expected, got: "nil / error")
            return
        }
        check(query, expected: expected, got: copy)
    }

    static func expectExpression(_ query: String, _ expected: String) {
        check(query, expected: expected, got: evaluate(query)?.expression ?? "nil")
    }

    static func expectError(_ query: String, _ expected: String, rates: CurrencyRates? = fx) {
        guard case .error(let message)? = evaluate(query, rates: rates)?.payload else {
            check(query, expected: "error: \(expected)", got: "nil / value")
            return
        }
        check(query, expected: expected, got: message)
    }

    static func expectNil(_ query: String) {
        check(query, expected: "nil", got: evaluate(query).map { "\($0.payload)" } ?? "nil")
    }
}
