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
        //    Важно: это НЕ должно добавлять точки перед числами.
        let verbs = [
            "купить","пойти","сходить","записаться",
            "позвонить","написать","сделать",
            "заказать","оплатить","встретиться",
            "убрать","приготовить","отправить",
            "посидеть","погулять"
        ]

        // Одна замена на все глаголы: " ... <verb> ..." -> ". <verb> ..."
        // (?<!^) — не в начале строки
        // \b — граница слова, чтобы не цеплять куски слов
        let verbsPattern = #"(?<!^)\s+\b("# + verbs.joined(separator: "|") + #")\b"#
        t = t.replacingOccurrences(of: verbsPattern, with: ". $1", options: .regularExpression)

        // 4) Мягко делим по " и " только если обе части достаточно длинные (чтобы не ломать "чай и кофе")
        //    и чтобы не дробить слишком агрессивно.
        t = t.replacingOccurrences(
            of: Patterns.softAndSplit,
            with: "$1. $2",
            options: .regularExpression
        )

        // 5) финальная чистка
        t = t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)

        // 6) точка в конце (чтобы деление по пунктуации работало стабильно)
        if let last = t.last, ".!?".contains(last) == false {
            t += "."
        }

        return t
    }

    private enum Patterns {
        // обе стороны должны начинаться с букв и иметь хотя бы 3 буквы подряд внутри
        // Пример: "купить молоко и хлеб" -> "купить молоко. хлеб"
        // Не трогаем: "чай и кофе" (слишком коротко), "iphone 15 и case" (много цифр)
        static let softAndSplit =
        #"\b([а-яa-z][^.!?;]{3,}?)\s+и\s+([а-яa-z][^.!?;]{3,}?)\b"#
    }
}
