import Foundation

final class DateParser {

    private struct ParseResult {
        var date: Date?
        var time: DateComponents?
        var title: String
    }

    private let calendar: Calendar
    private let locale: Locale

    init(calendar: Calendar = .current,
         locale: Locale = Locale(identifier: "ru_RU")) {
        self.calendar = calendar
        self.locale = locale
    }

    /// Парсит одну фразу (одну задачу) и возвращает:
    /// - Date? (если нашли дату или время)
    /// - String (очищенный title)
    func parse(from text: String) -> (Date?, String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, "") }

        var result = ParseResult(date: nil, time: nil, title: normalize(trimmed))

        // 0) Относительные даты: сегодня/завтра/послезавтра
        if let rel = extractRelativeDate(from: result.title) {
            result.date = rel.date
            result.title = rel.cleanedTitle
        }

        // 1) Время HH:MM (может быть "в 14:30" или "14:30")
        if let time = extractTimeHHMM(from: result.title) {
            result.time = time
            result.title = removeFirstMatch(from: result.title, pattern: Patterns.timeHHMM)
        }

        // 2) Время "в 17" (и НЕ "22-го")
        if result.time == nil, let time = extractTimeHourOnly(from: result.title) {
            result.time = time
            result.title = removeFirstMatch(from: result.title, pattern: Patterns.timeHourOnly)
        }

        // 3) Цифровая дата: 24.02 / 24/02 / 24-02 (опционально год)
        if result.date == nil, let d = extractNumericDate(from: result.title) {
            result.date = d.date
            result.title = d.cleanedTitle
        }

        // 4) Полная дата: "3 марта"
        if result.date == nil, let date = extractFullDate(from: result.title) {
            result.date = date
            result.title = removeFirstMatch(from: result.title, pattern: Patterns.fullDate)
        }

        // 5) День месяца ТОЛЬКО с маркером: "22-го", "22 числа", (по желанию "22 день/дня")
        if result.date == nil, let day = extractDayOfMonthMarked(from: result.title) {
            result.date = buildNearestFutureDateFromDay(day)
            result.title = removeFirstMatch(from: result.title, pattern: Patterns.dayMarked)
        }

        // Если ничего не нашли — просто отдаём title
        if result.date == nil && result.time == nil {
            return (nil, cleanTitle(result.title))
        }

        // Если даты нет, но время есть — базовая дата = сегодня
        let base = result.date ?? calendar.startOfDay(for: Date())
        let finalDate = merge(date: base, time: result.time)

        return (finalDate, cleanTitle(result.title))
    }

    // MARK: - Normalize & Clean

    private func normalize(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.lowercased(with: locale)

        // "22 - го" -> "22-го"
        s = s.replacingOccurrences(of: #"\s*-\s*"#,
                                   with: "-",
                                   options: .regularExpression)

        // множественные пробелы -> один
        s = s.replacingOccurrences(of: #"\s+"#,
                                   with: " ",
                                   options: .regularExpression)

        return s
    }

    private func cleanTitle(_ text: String) -> String {
        var s = text

        // Убираем лишние пробелы/тире
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(^-|-$)"#, with: "", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Patterns

    private enum Patterns {
        static let timeHHMM     = #"\b(?:в\s*)?\d{1,2}:\d{2}\b"#
        static let timeHourOnly = #"\bв\s*(\d{1,2})(?!\s*-?\s*го)\b"#

        static let fullDate = #"\b\d{1,2}\s*(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\b"#

        // ✅ ВАЖНО: день месяца — только с явным маркером, никаких голых чисел
        static let dayMarked = #"\b\d{1,2}\s*(?:-?\s*го|\s*числа|\s*дня|\s*день)\b"#

        // 24.02 / 24/02 / 24-02 (+ опционально год)
        static let numericDate = #"\b(\d{1,2})[./-](\d{1,2})(?:[./-](\d{2,4}))?\b"#
    }

    // MARK: - Relative dates

    private struct RelativeDateExtraction {
        let date: Date
        let cleanedTitle: String
    }

    private func extractRelativeDate(from t: String) -> RelativeDateExtraction? {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        func removeWord(_ word: String, from s: String) -> String {
            let pattern = #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#
            let out = s.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            return out.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if t.contains("послезавтра") {
            let date = calendar.date(byAdding: .day, value: 2, to: todayStart) ?? todayStart
            return .init(date: date, cleanedTitle: removeWord("послезавтра", from: t))
        }

        if t.contains("завтра") {
            let date = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return .init(date: date, cleanedTitle: removeWord("завтра", from: t))
        }

        if t.contains("сегодня") {
            return .init(date: todayStart, cleanedTitle: removeWord("сегодня", from: t))
        }

        return nil
    }

    // MARK: - Time extractors

    private func extractTimeHHMM(from t: String) -> DateComponents? {
        let pattern = #"\b(\d{1,2}):(\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let hRange = Range(match.range(at: 1), in: t),
              let mRange = Range(match.range(at: 2), in: t),
              let hour = Int(t[hRange]),
              let minute = Int(t[mRange]),
              (0...23).contains(hour),
              (0...59).contains(minute) else { return nil }

        return DateComponents(hour: hour, minute: minute)
    }

    private func extractTimeHourOnly(from t: String) -> DateComponents? {
        let pattern = #"\bв\s*(\d{1,2})(?!\s*-?\s*го)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let hRange = Range(match.range(at: 1), in: t),
              let hour = Int(t[hRange]),
              (0...23).contains(hour) else { return nil }

        return DateComponents(hour: hour, minute: 0)
    }

    // MARK: - Date extractors

    private struct NumericDateExtraction {
        let date: Date
        let cleanedTitle: String
    }

    private func extractNumericDate(from t: String) -> NumericDateExtraction? {
        guard let regex = try? NSRegularExpression(pattern: Patterns.numericDate) else { return nil }
        let range = NSRange(t.startIndex..<t.endIndex, in: t)

        guard let match = regex.firstMatch(in: t, range: range),
              let dRange = Range(match.range(at: 1), in: t),
              let mRange = Range(match.range(at: 2), in: t) else { return nil }

        let day = Int(t[dRange]) ?? 0
        let month = Int(t[mRange]) ?? 0
        guard (1...31).contains(day), (1...12).contains(month) else { return nil }

        var year: Int?
        if match.range(at: 3).location != NSNotFound,
           let yRange = Range(match.range(at: 3), in: t) {
            let yRaw = String(t[yRange])
            if yRaw.count == 2 {
                year = 2000 + (Int(yRaw) ?? 0)
            } else {
                year = Int(yRaw)
            }
        }

        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let usedYear = year ?? currentYear

        var comps = DateComponents()
        comps.year = usedYear
        comps.month = month
        comps.day = day
        comps.hour = 9
        comps.minute = 0

        guard var date = calendar.date(from: comps) else { return nil }

        // Если год не был задан и дата уже прошла — переносим на следующий год
        if year == nil, calendar.startOfDay(for: date) < calendar.startOfDay(for: now) {
            if let next = calendar.date(byAdding: .year, value: 1, to: date) {
                date = next
            }
        }

        let cleaned = removeFirstMatch(from: t, pattern: Patterns.numericDate)
        return .init(date: date, cleanedTitle: cleaned)
    }

    private func extractFullDate(from t: String) -> Date? {
        let months: [String: Int] = [
            "января": 1, "февраля": 2, "марта": 3, "апреля": 4,
            "мая": 5, "июня": 6, "июля": 7, "августа": 8,
            "сентября": 9, "октября": 10, "ноября": 11, "декабря": 12
        ]

        guard let regex = try? NSRegularExpression(pattern: Patterns.fullDate) else { return nil }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let fullRange = Range(match.range, in: t) else { return nil }

        let chunk = String(t[fullRange]) // "3 марта"
        let parts = chunk.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let day = Int(parts[0]) ?? 0
        let monthName = String(parts[1])
        guard (1...31).contains(day), let month = months[monthName] else { return nil }

        let now = Date()
        var comps = calendar.dateComponents([.year], from: now)
        comps.month = month
        comps.day = day
        comps.hour = 9
        comps.minute = 0

        guard var date = calendar.date(from: comps) else { return nil }

        // Если такая дата уже прошла — переносим на следующий год
        if calendar.startOfDay(for: date) < calendar.startOfDay(for: now) {
            if let nextYear = calendar.date(byAdding: .year, value: 1, to: date) {
                date = nextYear
            }
        }

        return date
    }

    private func extractDayOfMonthMarked(from t: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: Patterns.dayMarked) else { return nil }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let fullRange = Range(match.range, in: t) else { return nil }

        let chunk = String(t[fullRange]) // "22-го" / "22 числа"
        let numberPattern = #"\b(\d{1,2})\b"#
        guard let numRegex = try? NSRegularExpression(pattern: numberPattern) else { return nil }

        let r2 = NSRange(chunk.startIndex..<chunk.endIndex, in: chunk)
        guard let m2 = numRegex.firstMatch(in: chunk, range: r2),
              let dRange = Range(m2.range(at: 1), in: chunk),
              let day = Int(chunk[dRange]),
              (1...31).contains(day) else { return nil }

        return day
    }

    // MARK: - Nearest future day logic

    private func buildNearestFutureDateFromDay(_ day: Int) -> Date {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = day
        comps.hour = 9
        comps.minute = 0

        if let candidate = calendar.date(from: comps),
           calendar.startOfDay(for: candidate) >= todayStart {
            return candidate
        }

        return buildDateInNextMonth(day: day, hour: 9, minute: 0)
    }

    private func buildDateInNextMonth(day: Int, hour: Int, minute: Int) -> Date {
        let now = Date()

        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        comps.hour = hour
        comps.minute = minute

        guard let thisMonthFirst = calendar.date(from: comps),
              let nextMonthFirst = calendar.date(byAdding: .month, value: 1, to: thisMonthFirst),
              let range = calendar.range(of: .day, in: .month, for: nextMonthFirst) else {
            return now
        }

        let safeDay = min(day, range.count)

        var next = calendar.dateComponents([.year, .month], from: nextMonthFirst)
        next.day = safeDay
        next.hour = hour
        next.minute = minute

        return calendar.date(from: next) ?? now
    }

    // MARK: - Merge

    private func merge(date: Date, time: DateComponents?) -> Date {
        guard let time else { return date }

        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = time.hour
        comps.minute = time.minute
        return calendar.date(from: comps) ?? date
    }

    // MARK: - Remove first match

    private func removeFirstMatch(from t: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return t }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let r = Range(match.range, in: t) else { return t }

        var s = t
        s.removeSubrange(r)

        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
