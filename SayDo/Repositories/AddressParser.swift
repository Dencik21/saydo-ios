import Foundation

final class AddressParser {

    struct Result {
        let address: String?
        let cleanedTitle: String
    }

    private let markers: [String] = [
        // RU
        "улица", "ул\\.", "проспект", "пр-т", "переулок", "пер\\.", "площадь", "шоссе",
        // EN
        "street", "st\\.", "road", "rd\\.", "avenue", "ave\\.", "boulevard", "blvd",
        // DE
        "straße", "str\\.", "strasse", "weg", "platz", "allee",
        // PL
        "ulica", "ul\\.", "aleja", "al\\.", "plac"
    ]

    func parse(from text: String) -> Result {
        let t = normalize(text)
        guard !t.isEmpty else { return .init(address: nil, cleanedTitle: "") }

        // 1) "по адресу: ..." / "адрес ..."
        if let match = firstMatch(in: t, pattern: #"(?i)\b(по адресу|адрес)\s*[:\-]?\s*([^,;]+)"#) {
            let address = cleanupAddress(match.group(2))
            let cleaned = removeRange(from: t, range: match.range)
            return .init(
                address: address.isEmpty ? nil : address,
                cleanedTitle: cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            )
        }

        // 2) маркеры улиц (RU/EN/DE/PL)
        let joined = markers.joined(separator: "|")
        let pattern = "(?i)\\b((?:" + joined + ")\\s+[^\\n,;]+)"

        if let match = firstMatch(in: t, pattern: pattern) {
            let address = cleanupAddress(match.group(1))
            let cleaned = removeRange(from: t, range: match.range)
            return .init(
                address: address.isEmpty ? nil : address,
                cleanedTitle: cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            )
        }

        return .init(address: nil, cleanedTitle: t)
    }

    // MARK: - Helpers

    private func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func cleanupAddress(_ s: String) -> String {
        s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:;-"))
    }

    private func removeRange(from text: String, range: NSRange) -> String {
        guard let r = Range(range, in: text) else { return text }
        var copy = text
        copy.removeSubrange(r)
        return copy
    }

    private func firstMatch(in text: String, pattern: String)
    -> (range: NSRange, group: (Int) -> String)? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let m = re.firstMatch(in: text, options: [], range: full) else { return nil }

        func group(_ i: Int) -> String {
            let r = m.range(at: i)
            guard r.location != NSNotFound else { return "" }
            return ns.substring(with: r)
        }

        return (m.range, group)
    }
}
