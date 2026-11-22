import Foundation

enum TextNormalizer {
    /// Mažosios raidės be diakritikos: „Įjunk šviesą“ → „ijunk sviesa“.
    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "lt_LT"))
            .lowercased()
    }

    /// Suskaido tekstą į žodžius. Ženklas „%“ paverčiamas žodžiu „proc“.
    static func tokens(_ text: String) -> [String] {
        let prepared = fold(text).replacingOccurrences(of: "%", with: " proc ")
        return prepared
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Ar du žodžiai yra to paties žodžio formos (lietuvių kalbos linksniai):
    /// „svetaine“ ~ „svetaineje“, „miegamasis“ ~ „miegamajame“, „vonia“ ~ „vonioje“.
    static func sameWord(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = min(a.count, b.count)
        guard shorter >= 4 else { return false }
        let common = zip(a, b).prefix { $0 == $1 }.count
        let required = max(4, Int((Double(shorter) * 0.6).rounded(.up)))
        return common >= required
    }
}
