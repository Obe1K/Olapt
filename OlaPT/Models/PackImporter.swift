import Foundation

/// Импорт пользовательских словарей: JSON (тот же формат, что и у встроенных) или CSV/TSV.
enum PackImporter {

    enum ImportError: LocalizedError {
        case unreadable
        case empty
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "Не удалось прочитать файл. Нужен текстовый файл в кодировке UTF-8."
            case .empty:
                return "В файле не найдено ни одного слова."
            case .invalid(let message):
                return message
            }
        }
    }

    /// Пробует разобрать данные как JSON-словарь. Возвращает nil, если это не JSON нашего формата.
    static func parseJSON(_ data: Data) -> PackFile? {
        guard let pack = try? JSONDecoder().decode(PackFile.self, from: data) else { return nil }
        if pack.entries.isEmpty { return nil }
        return pack
    }

    /// Разбор CSV/TSV: на каждой строке «португальское слово; перевод 1 | перевод 2».
    static func parseCSV(text: String, name: String, lang: String) throws -> PackFile {
        let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        var entries: [PackEntry] = []
        var lineNumber = 0
        for rawLine in cleaned.components(separatedBy: .newlines) {
            lineNumber += 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            var delimiter: Character = ","
            if line.contains("\t") {
                delimiter = "\t"
            } else if line.contains(";") {
                delimiter = ";"
            }
            guard let cut = line.firstIndex(of: delimiter) else { continue }

            let quotes = CharacterSet(charactersIn: "\"' ")
            let pt = String(line[line.startIndex..<cut]).trimmingCharacters(in: quotes)
            let rest = String(line[line.index(after: cut)...])
            if pt.isEmpty { continue }

            if entries.isEmpty {
                let headerWords: Set<String> = ["pt", "portugues", "portuguese", "palavra", "word", "слово"]
                if headerWords.contains(TextUtil.fold(pt)) { continue }
            }

            var translations: [String] = []
            for piece in rest.split(whereSeparator: { "|;,\t".contains($0) }) {
                let t = String(piece).trimmingCharacters(in: quotes)
                if !t.isEmpty { translations.append(t) }
            }
            if translations.isEmpty { continue }
            entries.append(PackEntry(pt: pt, pos: nil, g: nil, f: nil, pl: nil, tr: translations,
                                     topic: nil, br: nil, note: nil))
        }
        if entries.isEmpty { throw ImportError.empty }
        let id = "import-" + UUID().uuidString.prefix(8).lowercased()
        return PackFile(format: 1, id: id, name: name, lang: lang, langName: Languages.name(lang),
                        variant: "pt-PT", version: 1, topics: nil, entries: entries)
    }

    /// Делает идентификатор безопасным для имени файла и уникальным.
    static func sanitizedID(_ id: String, existing: Set<String>) -> String {
        var base = ""
        for ch in id.lowercased() {
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                base.append(ch)
            } else {
                base.append("-")
            }
        }
        if base.isEmpty { base = "import" }
        var candidate = base
        var n = 2
        while existing.contains(candidate) {
            candidate = base + "-" + String(n)
            n += 1
        }
        return candidate
    }
}
