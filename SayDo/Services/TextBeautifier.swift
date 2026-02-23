import Foundation

final class TextBeautifier {

    // MARK: - Public

    func beautify(_ text: String) -> String {
        var t = normalizeSpaces(text)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        // Основное разбиение — токенами (надежнее regex для диктовки)
        t = splitByMarkersAndVerbs(t)

        // финальная чистка
        t = cleanupPunctuation(t)

        // точка в конце
        if let last = t.last, !".!?".contains(last) {
            t += "."
        }

        return t
    }

    /// Делает массив задач (1 строка = 1 задача)
    func splitTasks(_ text: String) -> [String] {
        let b = beautify(text)
        guard !b.isEmpty else { return [] }

        let parts = splitIntoSentences(b)

        return parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { capitalizeFirstLetter($0) }
            .filter { !$0.isEmpty }
            .filter { !isFiller($0) }
    }

    // MARK: - Dictionaries

    private let relativeMarkers: Set<String> = [
        "сегодня", "завтра", "послезавтра"
    ]

    private let transitionWords: Set<String> = [
        "потом", "затем", "далее", "дальше", "ещё", "еще"
    ]

    // База глаголов — расширяй по мере диктовок
    private let verbs: Set<String> = [
        "купить","пойти","сходить","записаться","позвонить","написать","сделать",
        "заказать","оплатить","встретиться","убрать","приготовить","отправить",
        "посидеть","погулять","съездить","зайти","забрать","проверить","прочитать",
        "помыть","поменять","заполнить","ответить","принести","завести","забронировать"
    ]

    /// Слова, после которых НЕ начинаем новую задачу перед глаголом
    /// (чтобы не было "я хочу. купить" / "надо. сделать")
    private let verbIntroBlockers: Set<String> = [
        "я","мы","ты","он","она","они",
        "хочу","хотел","хотела","хотим",
        "надо","нужно","можно","пожалуйста","давай"
    ]

    // MARK: - Core splitting

    private func splitByMarkersAndVerbs(_ text: String) -> String {
        let tokens = text.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return text }

        var out: [String] = []
        var prevWordLower: String? = nil

        var i = 0
        while i < tokens.count {
            let original = tokens[i]
            let lower = normalizeToken(original)

            // "после этого" -> разделитель (и выкидываем эти слова)
            if lower == "после", i + 1 < tokens.count {
                let nextLower = normalizeToken(tokens[i + 1])
                if nextLower == "этого" {
                    // граница задачи
                    ensureSentenceBoundary(&out)
                    i += 2
                    prevWordLower = nil
                    continue
                }
            }

            // Переходные слова (потом/затем/ещё...) — превращаем в границу и выкидываем
            if transitionWords.contains(lower) {
                ensureSentenceBoundary(&out)
                i += 1
                prevWordLower = nil
                continue
            }

            // Маркеры "сегодня/завтра/послезавтра" — это почти всегда новая задача/контекст
            if relativeMarkers.contains(lower), !out.isEmpty {

                // Смотрим, что дальше:
                let nextLower: String? = (i + 1 < tokens.count) ? normalizeToken(tokens[i + 1]) : nil

                // ✅ Если после маркера идёт глагол — это "Завтра позвонить..." => новая задача
                if let nextLower, verbs.contains(nextLower) {
                    ensureSentenceBoundary(&out)
                } else {
                    // ✅ Иначе это "позвонить ... завтра" => маркер относится к текущей задаче
                    // НИЧЕГО не делаем (не ставим точку)
                }
            }

            // Новый глагол внутри текста — старт новой задачи
            if verbs.contains(lower), shouldBreakBeforeVerb(prev: prevWordLower), !out.isEmpty {
                // если последнее слово уже заканчивается на пунктуацию — не дублируем
                ensureSentenceBoundary(&out)
            }

            out.append(original)
            prevWordLower = lower
            i += 1
        }

        return out.joined(separator: " ")
    }

    private func shouldBreakBeforeVerb(prev: String?) -> Bool {
        guard let prev else { return true }

        // ❗️НЕ разрезаем "завтра позвонить", "послезавтра сделать"
        if relativeMarkers.contains(prev) { return false }

        // и не разрезаем после вводных
        if verbIntroBlockers.contains(prev) { return false }

        return true
    }

    private func ensureSentenceBoundary(_ out: inout [String]) {
        guard let last = out.last else { return }

        // если уже стоит знак конца предложения — ничего не делаем
        if last.hasSuffix(".") || last.hasSuffix("!") || last.hasSuffix("?") || last.hasSuffix(";") {
            return
        }

        out[out.count - 1] = last + "."
    }

    // MARK: - Token helpers

    private func normalizeToken(_ s: String) -> String {
        // убираем пунктуацию по краям, приводим к lowercased
        let trimmed = s.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespacesAndNewlines))
        return trimmed.lowercased()
    }

    // MARK: - Helpers (formatting)

    private func normalizeSpaces(_ s: String) -> String {
        let replaced = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        return replaced.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func replaceRegex(_ text: String, pattern: String, with replacement: String) -> String {
        text.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
    }

    private func cleanupPunctuation(_ text: String) -> String {
        var t = text

        // ". ." -> "."
        t = replaceRegex(t, pattern: #"\.\s*\."#, with: ".")
        // " . " -> ". "
        t = replaceRegex(t, pattern: #"\s+\."#, with: ".")
        // пробелы вокруг запятой
        t = replaceRegex(t, pattern: #"\s*,\s*"#, with: ", ")
        // пробелы вокруг . ! ? ;
        t = replaceRegex(t, pattern: #"\s*([.!?;])\s*"#, with: "$1 ")
        // финальная нормализация
        t = normalizeSpaces(t).trimmingCharacters(in: .whitespacesAndNewlines)

        return t
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        var t = text

        // защитим частые аббревиатуры временным маркером
        let shield: [(String, String)] = [
            ("т.е.", "т<dot>е<dot>"),
            ("и т.д.", "и т<dot>д<dot>"),
            ("и т.п.", "и т<dot>п<dot>"),
            ("руб.", "руб<dot>"),
            ("коп.", "коп<dot>"),
            ("ул.", "ул<dot>"),
            ("г.", "г<dot>"),
            ("д.", "д<dot>")
        ]
        for (a, b) in shield {
            t = t.replacingOccurrences(of: a, with: b, options: .caseInsensitive)
        }

        let parts = t.components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))

        return parts.map { part in
            var p = part
            for (a, b) in shield {
                p = p.replacingOccurrences(of: b, with: a)
            }
            return p
        }
    }

    private func capitalizeFirstLetter(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first else { return t }
        return String(first).uppercased() + t.dropFirst()
    }

    private func isFiller(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let low = trimmed.lowercased()
        let fillers: Set<String> = ["и", "ну", "короче", "в общем", "типа", "значит", "так", "ладно"]
        if fillers.contains(low) { return true }

        if trimmed.count < 3 { return true }
        return false
    }
}
