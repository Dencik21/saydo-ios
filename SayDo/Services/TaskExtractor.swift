import Foundation

final class TaskExtractor {

    private let dateParser = DateParser()
    private let beautifier = TextBeautifier()

    func extract(from text: String) -> [TaskModel] {

        // 1) Beautify (пунктуация/разделители/мягкое разбиение)
        var prepared = beautifier.beautify(text)
        print("AFTER BEAUTIFY:", prepared)
        guard !prepared.isEmpty else { return [] }

        // 2) Если внутри фразы внезапно встречается "5 марта" и т.п. — поможем разрезать
        prepared = prepared.replacingOccurrences(
            of: Patterns.splitBeforeDateMarker,
            with: ". $1",
            options: .regularExpression
        )

        // 3) Разбиваем на части АККУРАТНО (без руб. / т.д. / т.п. и т.п.)
        let parts = splitSentencesSafe(prepared)
            .map(clean)
            .filter(isGoodTask)

        // 4) Создание задач + перенос даты (контекст)
        var result: [TaskModel] = []
        var currentDate: Date? = nil

        for part in parts {
            // Если часть содержит явный относительный маркер, мы ожидаем обновление контекста
            let hasRelativeMarker = containsRelativeDateMarker(part)

            let (date, cleanedTitle) = dateParser.parse(from: part)

            // Если парсер нашёл дату — обновляем контекст
            if let d = date {
                currentDate = d
            } else if hasRelativeMarker {
                // Если маркер был, а дату не нашли (ошибка распознавания) —
                // безопаснее НЕ тянуть старую дату дальше
                currentDate = nil
            }

            let title = capitalizeFirst(cleanedTitle)
            guard isGoodTask(title) else { continue }

            result.append(
                TaskModel(
                    title: title,
                    dueDate: currentDate,
                    isDone: false,
                    createdAt: .now
                )
            )
        }

        return result
    }

    // MARK: - Sentence splitting (safe)

    private func splitSentencesSafe(_ text: String) -> [String] {
        var t = text
            .replacingOccurrences(of: "\n", with: ". ")
            .replacingOccurrences(of: "…", with: ". ")
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return [] }

        // Защищаем самые частые аббревиатуры, которые НЕ должны резаться по точке
        // (можешь добавлять по мере диктовок)
        let shields: [(pattern: String, token: String)] = [
            (#"(?i)\bруб\."#, "руб<dot>"),
            (#"(?i)\bкоп\."#, "коп<dot>"),
            (#"(?i)\bт\.д\."#, "т<dot>д<dot>"),
            (#"(?i)\bт\.п\."#, "т<dot>п<dot>"),
            (#"(?i)\bт\.е\."#, "т<dot>е<dot>"),
            (#"(?i)\bул\."#, "ул<dot>"),
            (#"(?i)\bд\."#, "д<dot>"),
            (#"(?i)\bг\."#, "г<dot>")
        ]

        for s in shields {
            t = t.replacingOccurrences(of: s.pattern, with: s.token, options: .regularExpression)
        }

        // Делим по . ! ? ;  (после защиты аббревиатур)
        let rawParts = t.components(separatedBy: CharacterSet(charactersIn: ".!?;"))

        // Возвращаем точки обратно
        let restored = rawParts.map { part -> String in
            var p = part
            p = p.replacingOccurrences(of: "<dot>", with: ".")
            return p
        }

        return restored
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Patterns

    private enum Patterns {
        /// Вставляет точку перед маркером даты, если он встречается НЕ в начале фразы
        /// и не является "2 раза", "3 штуки" и т.п.
        static let splitBeforeDateMarker =
        #"(?<!^)\s+((?:\d{1,2}\s*(?:-?\s*(?:го|е)|\s*числа))|\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?|\d{1,2}\s*(?:января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря))\b"#
    }

    // MARK: - Relative marker detection

    private func containsRelativeDateMarker(_ s: String) -> Bool {
        // Минимальный набор (можешь расширять)
        let pattern = #"(?i)\b(сегодня|завтра|послезавтра|в\s+понедельник|во\s+вторник|в\s+среду|в\s+четверг|в\s+пятницу|в\s+субботу|в\s+воскресенье)\b"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Clean

    private func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // убираем разговорные префиксы
        let trashPrefixes = [
            "итак", "ну", "короче", "в общем",
            "значит", "так", "получается"
        ]
        for w in trashPrefixes {
            if t.lowercased().hasPrefix(w + " ") {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // убираем "мне нужно / надо / нужно"
        let prefixes = ["мне нужно ", "надо ", "нужно "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // удаляем хвостовой союз
        t = t.replacingOccurrences(
            of: #"\s+\b(и|а|но|да)\b\s*$"#,
            with: "",
            options: .regularExpression
        )

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation

    private func isGoodTask(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }

        let low = trimmed.lowercased()

        // мусор
        if ["и", "а", "но", "да", "ну", "короче", "значит"].contains(low) { return false }

        // допускаем короткие “нормальные” команды
        let shortAllow = ["купить", "позвонить", "записаться", "сходить", "пойти", "написать"]
        if trimmed.count < 4 {
            return shortAllow.contains(where: { low.hasPrefix($0) })
        }

        // минимум букв
        let letters = low.filter { $0.isLetter }.count
        return letters >= 3
    }

    // MARK: - Capitalize

    private func capitalizeFirst(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return t }
        return String(first).uppercased() + t.dropFirst()
    }
}
