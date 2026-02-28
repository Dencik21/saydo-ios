import Foundation

enum TaskPriority: Int {
    case normal = 0
    case important = 1
    case urgent = 2
}

struct PriorityParseResult {
    let priority: TaskPriority
    let cleanedText: String
}

enum PriorityParser {

    static func extract(from text: String) -> PriorityParseResult {
        let normalized = normalize(text)

        // 1) Сначала URGENT
        if matchesAny(normalized, patterns: urgentPatterns) {
            return .init(priority: .urgent, cleanedText: removeAny(from: text, patterns: urgentPatterns))
        }

        // 2) Потом IMPORTANT
        if matchesAny(normalized, patterns: importantPatterns) {
            return .init(priority: .important, cleanedText: removeAny(from: text, patterns: importantPatterns))
        }

        return .init(priority: .normal, cleanedText: text)
    }

    // MARK: - Patterns (regex)
    // ⚠️ ВАЖНО: используем \b и \s+ чтобы ловить "очень важно" как фразу

    private static let urgentPatterns: [String] = [
        #"\bсрочно\b"#,
        #"\bочень\s+срочно\b"#,
        #"\bпрям\s+срочно\b"#,
        #"\bнемедленно\b"#,
        #"\bкак\s+можно\s+скорее\b"#,
        #"\bв\s+крайние\s+сроки\b"#,
        #"\bв\s+кратчайшие\s+сроки\b"#,
        #"\bдо\s+конца\s+дня\b"#,

        // EN/DE (на будущее)
        #"\burgent\b"#,
        #"\basap\b"#,
        #"\bsofort\b"#,
        #"\bdringend\b"#
    ]

    private static let importantPatterns: [String] = [
        #"\bважно\b"#,
        #"\bочень\s+важно\b"#,
        #"\bкрайне\s+важно\b"#,
        #"\bэто\s+важно\b"#,
        #"\bприоритет\b"#,
        #"\bприоритетно\b"#,
        #"\bнеобходимо\b"#,          // ← реши сам: important (как сейчас) или urgent

        // EN/DE
        #"\bimportant\b"#,
        #"\bpriority\b"#,
        #"\bwichtig\b"#
    ]

    // MARK: - Helpers

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matchesAny(_ text: String, patterns: [String]) -> Bool {
        for p in patterns {
            let pattern = #"(?i)\#(p)"#
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        return false
    }

    private static func removeAny(from original: String, patterns: [String]) -> String {
        var result = original
        for p in patterns {
            let pattern = #"(?i)\#(p)"#
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }

        // чистим мусор типа ", ,", двойные пробелы
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"^\s*[,:-]\s*"#, with: "", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result
    }
}
