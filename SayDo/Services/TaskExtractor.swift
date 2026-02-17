import Foundation

final class TaskExtractor {

    func extract(from text: String) -> [TaskItem] {
        // 1) базовое разбиение по пунктуации
        var parts = text
            .replacingOccurrences(of: "\n", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?;"))
            .map(clean)
            .filter { !$0.isEmpty }

        // 2) если какой-то пункт очень длинный — дробим по связкам
        parts = parts.flatMap { part in
            part.count > 55 ? splitBySoftConnectors(part) : [part]
        }

        // 3) финальная чистка + фильтр мусора
        let final = parts
            .map(clean)
            .filter(isGoodTask)

        return final.map { TaskItem(title: capitalizeFirst($0)) }
    }

    // MARK: - Helpers

    private func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // убрать двойные пробелы
        while t.contains("  ") { t = t.replacingOccurrences(of: "  ", with: " ") }

        // типовые разговорные начала (срезаем, а не выкидываем)
        let leadingTrash = [
            "итак", "ну", "короче", "в общем", "значит", "так", "получается"
        ]
        for w in leadingTrash {
            if t.lowercased().hasPrefix(w + " ") {
                t = String(t.dropFirst(w.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // убрать “мне нужно” в начале — часто это лишнее
        let prefixes = ["мне нужно ", "надо ", "нужно "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return t
    }

    private func isGoodTask(_ s: String) -> Bool {
        let low = s.lowercased()

        // слишком короткие/пустые
        if s.count < 4 { return false }

        // явные “закрывашки” и мусор
        let trashExact = [
            "всё", "все", "я ну вот и всё", "ну вот и всё", "что дальше", "в принципе всё"
        ]
        if trashExact.contains(low) { return false }

        // если почти нет букв (редкий случай)
        let letters = low.filter { $0.isLetter }.count
        if letters < 3 { return false }

        return true
    }

    private func splitBySoftConnectors(_ chunk: String) -> [String] {
        let connectors = [
            " также ", " и еще ", " и ещё ", " ещё ", " еще ",
            " может быть ", " плюс ", " а еще ", " а ещё ", " и "
        ]

        var result = [chunk]
        for c in connectors {
            result = result.flatMap { $0.components(separatedBy: c) }
        }
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                     .filter { !$0.isEmpty }
    }

    private func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
}
