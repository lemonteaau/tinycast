import Foundation

extension CalcQuantity {
    /// A preferred currency outranks the region's, which answers for amounts typed in it instead.
    static func conversionTarget(
        _ preferred: String?, region: String?, from: CurrencyDef
    ) -> CurrencyDef? {
        guard let preferred = preferred.flatMap({ CalcCurrency.byName[$0.lowercased()] }),
            preferred.code != from.code
        else { return regionTarget(region, from: from) }
        return preferred
    }
}
