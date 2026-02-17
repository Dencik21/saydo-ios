import Foundation

final class TaskExtractor {

    private let dateParser = DateParser()
    private let beautifier = TextBeautifier()

    func extract(from text: String) -> [TaskItem] {

        // 1️⃣ Beautify
        var prepared = beautifier.beautify(text)

        // 2️⃣ ГЛАВНЫЙ ФИКС: если речь пришла одной строкой, разделяем по датам:
        // "22-го ... 21-го ..." -> "22-го ... . 21-го ..."
        prepared = prepared.replacingOccurrences(
            of: #"(?<!^)\s+(\d{1,2}\s*(?:-?\s*го)?)(?=\s)"#,
            with: ". $1",
            options: .regularExpression
        )

        // 3️⃣ Делим по точкам/переносам
        var parts = prepared
            .replacingOccurrences(of: "\n", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?;"))
            .map(clean)
            .filter { !$0.isEmpty }

        // 4️⃣ Делим по глаголам (если в одном куске несколько задач)
        parts = parts.flatMap { splitByVerbs($0) }

        // 5️⃣ Финальная чистка
        let final = parts
            .map(clean)
            .filter(isGoodTask)

        // 6️⃣ Создание задач с переносом даты (контекст)
        var result: [TaskItem] = []
        var currentDate: Date? = nil

        for raw in final {

            // парсим одну фразу
            let (date, cleaned) = dateParser.parse(from: raw)

            // если нашли дату/время — обновляем контекст
            if let d = date {
                currentDate = d
            }

            let title = capitalizeFirst(cleaned.trimmingCharacters(in: .whitespacesAndNewlines))
            if title.count < 3 { continue }

            result.append(
                TaskItem(
                    title: title,
                    dueDate: currentDate
                )
            )
        }

        return result
    }

    // MARK: - Clean

    private func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // убрать разговорный мусор
        let trashPrefixes = [
            "итак","ну","короче","в общем",
            "значит","так","получается"
        ]

        for w in trashPrefixes {
            if t.lowercased().hasPrefix(w + " ") {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // убрать "мне нужно", "надо"
        let prefixes = ["мне нужно ", "надо ", "нужно "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        // убрать хвосты типа "и", "а", "но"
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

        if ["и","а","но","да","получится"].contains(trimmed) {
            return false
        }

        let letters = trimmed.filter { $0.isLetter }.count
        if letters < 3 { return false }

        return true
    }

    // MARK: - Split by verbs

    private func splitByVerbs(_ text: String) -> [String] {

        let verbs = [
            "купить","пойти","сходить","записаться",
            "позвонить","написать","сделать",
            "заказать","оплатить","встретиться",
            "убрать","приготовить","отправить",
            "посидеть","погулять"
        ]

        let pattern = #"(?<!^)\s+\b("# + verbs.joined(separator: "|") + #")\b"#

        let withDots = text.replacingOccurrences(
            of: pattern,
            with: ". $1",
            options: .regularExpression
        )

        return withDots
            .components(separatedBy: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Capitalize

    private func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
}
