import Foundation

final class TextBeautifier {

    func beautify(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        t = t.lowercased()

        // 1) нормализуем пробелы
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // 2) разделители "потом/затем/ещё" → точки
        let separators = [
            " и потом ", " потом ", " затем ", " после этого ", " далее ", " потом же ",
            " дальше ", " и дальше ", " еще ", " ещё ", " и еще ", " и ещё ",
            " что еще ", " что ещё "
        ]
        for s in separators {
            t = t.replacingOccurrences(of: s, with: ". ")
        }

        // 3) Глаголы-действия → ставим точку ПЕРЕД новым действием (если оно не в начале)
        let verbs = [
            "купить","пойти","сходить","записаться",
            "позвонить","написать","сделать",
            "заказать","оплатить","встретиться",
            "убрать","приготовить","отправить",
            "посидеть","погулять"
        ]

        let verbsPattern = #"(?<!^)\s+\b("# + verbs.joined(separator: "|") + #")\b"#
        t = t.replacingOccurrences(of: verbsPattern, with: ". $1", options: .regularExpression)

        // 4) Мягко делим по " и "
        t = t.replacingOccurrences(
            of: Patterns.softAndSplit,
            with: "$1. $2",
            options: .regularExpression
        )

        // 5) финальная чистка
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)

        // 6) точка в конце
        if let last = t.last, ".!?".contains(last) == false {
            t += "."
        }

        return t
    }

    /// ✅ Новый метод: превращает диктовку в массив задач
    func splitTasks(_ text: String) -> [String] {
        let beautified = beautify(text)
        guard !beautified.isEmpty else { return [] }

        return beautified
            .components(separatedBy: CharacterSet(charactersIn: ".!?;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private enum Patterns {
        static let softAndSplit =
        #"\b([а-яa-z][^.!?;]{3,}?)\s+и\s+([а-яa-z][^.!?;]{3,}?)\b"#
    }
}
