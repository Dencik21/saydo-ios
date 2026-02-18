import Foundation

final class TaskExtractor {

    private let dateParser = DateParser()
    private let beautifier = TextBeautifier()

    /// Из текста делает массив SwiftData-моделей (TaskModel)
    func extract(from text: String) -> [TaskModel] {

        // 1) Beautify
        var prepared = beautifier.beautify(text)

        // 2) Разделяем по явным маркерам даты (не трогаем "2 раза", "3 штуки")
        prepared = prepared.replacingOccurrences(
            of: Patterns.splitBeforeDateMarker,
            with: ". $1",
            options: .regularExpression
        )

        // 3) Делим по пунктуации/переносам
        let parts = prepared
            .replacingOccurrences(of: "\n", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?;"))
            .map(clean)
            .filter { !$0.isEmpty }

        // 4) Финальная фильтрация
        let final = parts
            .map(clean)
            .filter(isGoodTask)

        // 5) Создание задач с переносом даты (контекст)
        var result: [TaskModel] = []
        var currentDate: Date? = nil

        for raw in final {
            let (date, cleaned) = dateParser.parse(from: raw)

            if let d = date { currentDate = d }

            let title = capitalizeFirst(cleaned)
            if title.count < 3 { continue }

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

    // MARK: - Patterns

    private enum Patterns {
        static let splitBeforeDateMarker =
        #"(?<!^)\s+((?:\d{1,2}\s*(?:-?\s*го|\s*числа))|\d{1,2}[./-]\d{1,2}(?:[./-]\d{2,4})?|\d{1,2}\s*(?:января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря))\b"#
    }

    // MARK: - Clean

    private func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        let trashPrefixes = [
            "итак", "ну", "короче", "в общем",
            "значит", "так", "получается"
        ]

        for w in trashPrefixes {
            if t.lowercased().hasPrefix(w + " ") {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        let prefixes = ["мне нужно ", "надо ", "нужно "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        t = t.replacingOccurrences(
            of: #"\s+\b(и|а|но|да)\b\s*$"#,
            with: "",
            options: .regularExpression
        )

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation

    private func isGoodTask(_ s: String) -> Bool {
        let trimmed = s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 4 { return false }
        if ["и","а","но","да","получится"].contains(trimmed) { return false }

        let letters = trimmed.filter { $0.isLetter }.count
        if letters < 3 { return false }

        return true
    }

    // MARK: - Capitalize

    private func capitalizeFirst(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return t }
        return String(first).uppercased() + t.dropFirst()
    }
}
