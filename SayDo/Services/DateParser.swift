import Foundation

final class DateParser {

    // MARK: - Types

    private struct ParseResult {
        var date: Date?
        var time: DateComponents?
        var title: String
    }

    // MARK: - Properties

    private let calendar: Calendar
    private let locale: Locale

    // MARK: - Init

    init(calendar: Calendar = .current,
         locale: Locale = Locale(identifier: "ru_RU")) {
        self.calendar = calendar
        self.locale = locale
    }

    // MARK: - Public

    /// Парсит одну фразу (одну задачу) и возвращает:
    /// - Date? (если нашли дату или время)
    /// - String (очищенный title)
    func parse(from text: String) -> (Date?, String) {
        var result = ParseResult(date: nil, time: nil, title: normalize(text))

        // 1) Время HH:MM
        if let time = extractTimeHHMM(from: result.title) {
            result.time = time
            result.title = removeFirstMatch(from: result.title,
                                            pattern: Patterns.timeHHMM)
        }

        // 2) Время "в 17" (без конфликтов с "22-го")
        if result.time == nil, let time = extractTimeHourOnly(from: result.title) {
            result.time = time
            result.title = removeFirstMatch(from: result.title,
                                            pattern: Patterns.timeHourOnly)
        }

        // 3) Полная дата "3 марта"
        if let date = extractFullDate(from: result.title) {
            result.date = date
            result.title = removeFirstMatch(from: result.title,
                                            pattern: Patterns.fullDate)
        }
        // 4) Только день "22", "22-го", "22 числа"
        else if let day = extractDayOfMonth(from: result.title) {
            result.date = buildNearestFutureDateFromDay(day)
            result.title = removeFirstMatch(from: result.title,
                                            pattern: Patterns.dayOnly)
        }

        // Если ничего не нашли — просто возвращаем очищенный title
        if result.date == nil && result.time == nil {
            return (nil, cleanTitle(result.title))
        }

        // Если даты нет, но время есть — базовая дата = today
        let base = result.date ?? Date()
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

        // если вдруг остались хвосты
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(^-|-$)"#, with: "", options: .regularExpression)

        // мусор-слово (по желанию)
        s = s.replacingOccurrences(of: #"\bраз\b"#, with: "", options: .regularExpression)

        // финальная нормализация пробелов
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Patterns

    private enum Patterns {
        static let timeHHMM = #"\b(?:в\s*)?\d{1,2}:\d{2}\b"#
        static let timeHourOnly = #"\bв\s*\d{1,2}(?!\s*-?\s*го)\b"#
        static let fullDate = #"\b\d{1,2}\s*(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)\b"#
        static let dayOnly = #"\b\d{1,2}\s*(?:-?\s*го)?\s*(?:числа)?\b"#
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

        let chunk = String(t[fullRange])            // "3 марта"
        let parts = chunk.split(separator: " ")
        guard parts.count >= 2 else { return nil }

        let day = Int(parts[0]) ?? 1
        let monthName = String(parts[1])
        guard let month = months[monthName], (1...31).contains(day) else { return nil }

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

    private func extractDayOfMonth(from t: String) -> Int? {
        let pattern = #"\b(\d{1,2})(?:\s*(?:-?\s*го))?(?:\s*числа)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(t.startIndex..<t.endIndex, in: t)
        guard let match = regex.firstMatch(in: t, range: range),
              let r = Range(match.range(at: 1), in: t),
              let n = Int(t[r]),
              (1...31).contains(n) else { return nil }

        return n
    }

    // MARK: - Nearest future day logic (FIX for "19-го -> today")

    /// Делает ближайший будущий день месяца:
    /// - если day >= todayDay → в этом месяце
    /// - если day < todayDay → в следующем месяце
    private func buildNearestFutureDateFromDay(_ day: Int) -> Date {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // кандидат в текущем месяце
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = day
        comps.hour = 9
        comps.minute = 0

        if let candidate = calendar.date(from: comps) {
            if calendar.startOfDay(for: candidate) >= todayStart {
                return candidate
            }
        }

        // иначе — следующий месяц (без падений на 31 число)
        return buildDateInNextMonth(day: day, hour: 9, minute: 0)
    }

    private func buildDateInNextMonth(day: Int, hour: Int, minute: Int) -> Date {
        let now = Date()

        // берём 1-е число следующего месяца
        var comps = calendar.dateComponents([.year, .month], from: now)
        comps.day = 1
        comps.hour = hour
        comps.minute = minute

        guard let thisMonthFirst = calendar.date(from: comps),
              let nextMonthFirst = calendar.date(byAdding: .month, value: 1, to: thisMonthFirst),
              let range = calendar.range(of: .day, in: .month, for: nextMonthFirst) else {
            return now
        }

        let lastDay = range.count
        let safeDay = min(day, lastDay)

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
