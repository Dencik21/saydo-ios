import Foundation

final class TaskExtractor {

    private let dateParser = DateParser()
    private let addressParser = AddressParser()
    private let beautifier = TextBeautifier()

    // ✅ Главный метод: парсим в Draft (правильный слой)
    func extractDrafts(from text: String) -> [TaskDraft] {

        var prepared = beautifier.beautify(text)
        guard !prepared.isEmpty else { return [] }

       prepared = prepared.replacingOccurrences(
            of: Patterns.splitBeforeDateMarker,
            with: ". $1",
            options: .regularExpression
        )
     
        let parts = splitSentencesSafe(prepared)
            .map(clean)
            .filter(isGoodTask)

        var result: [TaskDraft] = []
        var currentDate: Date? = nil

        for part in parts {
            let hasRelativeMarker = containsRelativeDateMarker(part)

            let (date, cleanedTitle) = dateParser.parse(from: part)

            // ✅ priority parsing
            let pr = PriorityParser.extract(from: part)               // ✅ берём из исходника
            let priorityRaw = pr.priority.rawValue

            // ✅ чистим title уже из cleanedTitle, но если там “важно” уже удалили — ок, приоритет всё равно сохранится
            let cleanedTitleAfterPriority = PriorityParser
                .extract(from: cleanedTitle)
                .cleanedText

            // ✅ address parsing
            let addr = addressParser.parse(from: cleanedTitleAfterPriority)
            let cleanedTitle2 = addr.cleanedTitle
            let extractedAddress = addr.address

            if let d = date {
                currentDate = d
            } else if hasRelativeMarker {
                currentDate = nil
            }

            let title = capitalizeFirst(cleanedTitle2)
            guard isGoodTask(title) else { continue }
            
            result.append(
                TaskDraft(
                    title: title,
                    dueDate: currentDate,
                    address: extractedAddress,
                    coordinate: nil,
                    reminderEnabled: false,
                    reminderMinutesBefore: 10,
                    priorityRaw: priorityRaw
                )
            )
        }

        return result
    }

    // ✅ Если тебе прямо сейчас надо "сразу TaskModel"
    func extractModels(from text: String) -> [TaskModel] {
        extractDrafts(from: text).map { TaskModel(from: $0) }
    }

    // MARK: - Sentence splitting (safe)

    private func splitSentencesSafe(_ text: String) -> [String] {
        var t = text
            .replacingOccurrences(of: "\n", with: ". ")
            .replacingOccurrences(of: "…", with: ". ")

        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        let shields: [(pattern: String, token: String)] = [
            (#"(?i)\bруб\."#, "руб<dot>"),
            (#"(?i)\bкоп\."#, "коп<dot>"),
            (#"(?i)\bт\.д\."#, "т<dot>д<dot>"),
            (#"(?i)\bт\.п\."#, "т<dot>п<dot>"),
            (#"(?i)\bт\.е\."#, "т<dot>е<dot>"),
            (#"(?i)\bул\."#, "ул<dot>"),
            (#"(?i)\bд\."#, "д<dot>"),
            (#"(?i)\bг\."#, "г<dot>"),

            // ✅ important for addresses
            (#"(?i)\bul\."#, "ul<dot>"),
            (#"(?i)\bal\."#, "al<dot>"),
            (#"(?i)\bstr\."#, "str<dot>"),
            (#"(?i)\bst\."#, "st<dot>"),
            (#"(?i)\brd\."#, "rd<dot>"),
            (#"(?i)\bave\."#, "ave<dot>")
        ]

        for s in shields {
            t = t.replacingOccurrences(of: s.pattern, with: s.token, options: .regularExpression)
        }

        let rawParts = t.components(separatedBy: CharacterSet(charactersIn: ".!?;"))

        let restored = rawParts.map { part -> String in
            part.replacingOccurrences(of: "<dot>", with: ".")
        }

        return restored
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Patterns

    private enum Patterns {
        static let splitBeforeDateMarker =
        #"(?<!^)\s+((?:\d{1,2}\s*(?:-?\s*(?:го|е)|\s*числа))|\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?|\d{1,2}\s*(?:января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря))\b"#
    }

    // MARK: - Relative marker detection

    private func containsRelativeDateMarker(_ s: String) -> Bool {
        let pattern = #"(?i)\b(сегодня|завтра|послезавтра|в\s+понедельник|во\s+вторник|в\s+среду|в\s+четверг|в\s+пятницу|в\s+субботу|в\s+воскресенье)\b"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Clean

    private func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        let trashPrefixes = ["итак", "ну", "короче", "в общем", "значит", "так", "получается"]
        for w in trashPrefixes {
            if t.lowercased().hasPrefix(w + " ") {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }

        let prefixes = ["мне нужно ", "надо ", "нужно "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: CharacterSet.whitespaces)
            }
        }

        t = t.replacingOccurrences(
            of: #"\s+\b(и|а|но|да)\b\s*$"#,
            with: "",
            options: .regularExpression
        )

        return t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    // MARK: - Validation

    private func isGoodTask(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        let low = trimmed.lowercased()

        if ["и", "а", "но", "да", "ну", "короче", "значит"].contains(low) { return false }

        let shortAllow = ["купить", "позвонить", "записаться", "сходить", "пойти", "написать"]
        if trimmed.count < 4 {
            return shortAllow.contains(where: { low.hasPrefix($0) })
        }

        let letters = low.filter { $0.isLetter }.count
        return letters >= 3
    }

    // MARK: - Capitalize

    private func capitalizeFirst(_ s: String) -> String {
        let t = s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard let first = t.first else { return t }
        return String(first).uppercased() + t.dropFirst()
    }
}
