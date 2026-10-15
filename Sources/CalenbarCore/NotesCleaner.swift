import Foundation

/// Turns event notes into readable plain text. Google Calendar often stores descriptions as HTML.
public enum NotesCleaner {
    private static let entities = [
        "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&apos;": "'",
    ]

    public static func clean(_ notes: String?) -> String? {
        guard var text = notes else { return nil }

        let isHTML = text.range(of: "<[a-zA-Z/][^>]*>", options: .regularExpression) != nil
        if isHTML {
            text = text.replacingOccurrences(
                of: "<br\\s*/?>|</(p|div|li|h[1-6])>|</?(ul|ol)>",
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        for (entity, character) in entities {
            text = text.replacingOccurrences(of: entity, with: character)
        }

        var lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        // Google Calendar appends a Meet invitation block fenced by "-::~:~::~…" lines; the Join button covers it.
        if let footer = lines.firstIndex(where: { $0.hasPrefix("-::~:~::") }) {
            lines.removeSubrange(footer...)
        }
        var kept: [String] = []
        for line in lines {
            if line.isEmpty {
                // HTML markup produces stray empty lines; plain text keeps at most one blank line.
                if !isHTML, kept.last?.isEmpty == false {
                    kept.append(line)
                }
            } else {
                kept.append(line)
            }
        }
        let result = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}
