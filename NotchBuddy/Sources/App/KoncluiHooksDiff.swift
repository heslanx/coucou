import Foundation

// Koncluí: what an install or a removal changes in an agent's file, in words and in lines. The installers return the whole
// file they are about to write; showing all of it hides the few lines that are Koncluí's among the person's own
// (docs/konclui/UX.md, 1.3 habit 5: show exactly what will change). This compares the file as it is with the file as it
// will be and keeps the difference. Pure Foundation, so scripts/konclui/test-page-rules.sh checks it.

struct KoncluiHooksDiff: Equatable, Sendable {

    /// What happens to the file, for the sentence above the lines.
    enum Summary: Equatable, Sendable {
        /// Koncluí's entries are added to a file that has others (or none).
        case adds(entries: Int)
        case removes(entries: Int)
        case updates(entries: Int)
        /// A file of Koncluí's own (a plugin) is rewritten.
        case updatesFile
        /// Koncluí's own file (a plugin, Copilot's hooks) does not exist yet.
        case creates
        case deletes
        case nothing
    }

    let summary: Summary
    /// Lines that appear, as they will be written (indentation kept).
    let added: [String]
    /// Lines that disappear.
    let removed: [String]
    /// Hook commands of other tools that stay in the file: "the other N stay as they are".
    let othersKept: Int
    /// The file as it will be written, for the "see the whole file" disclosure.
    let whole: String

    /// The installers answer a removal of a file of Koncluí's own with this line instead of the file.
    static let deletionMarker = "(will delete "

    /// `original` is the file as it is now (nil when it does not exist), `pending` what the installer will write.
    static func compute(original: String?, pending: String) -> KoncluiHooksDiff {
        if pending.hasPrefix(deletionMarker) {
            let old = lines(original ?? "")
            return KoncluiHooksDiff(summary: .deletes, added: [], removed: old, othersKept: 0, whole: pending)
        }
        // Both sides go through one serializer, so a file formatted another way does not read as a change in every line.
        let after = canonical(pending)
        let before = original.map(canonical)
        let afterLines = lines(after)
        guard let before, !before.isEmpty else {
            return KoncluiHooksDiff(summary: .creates, added: afterLines, removed: [], othersKept: 0, whole: after)
        }
        let beforeLines = lines(before)
        let difference = afterLines.difference(from: beforeLines)
        var added: [String] = [], removed: [String] = []
        for change in difference {
            switch change {
            case .insert(_, let line, _): added.append(line)
            case .remove(_, let line, _): removed.append(line)
            }
        }
        // `difference` lists removals first and then insertions in file order; show the file's order.
        added = orderedLikeFile(added, in: afterLines)
        removed = orderedLikeFile(removed, in: beforeLines)
        let addedEntries = added.filter(isKoncluiCommand).count
        let removedEntries = removed.filter(isKoncluiCommand).count
        let others = afterLines.filter { isCommandLine($0) && !isKoncluiCommand($0) }.count
        let summary: Summary
        switch (addedEntries, removedEntries) {
        case (0, 0):
            // Lines changed but no command did (a timeout, a matcher): the entries Koncluí keeps in the file are updated.
            let owned = afterLines.filter(isKoncluiCommand).count
            summary = added.isEmpty && removed.isEmpty ? .nothing : (owned > 0 ? .updates(entries: owned) : .updatesFile)
        case (let a, 0): summary = .adds(entries: a)
        case (0, let r): summary = .removes(entries: r)
        case (let a, let r): summary = .updates(entries: max(a, r))
        }
        return KoncluiHooksDiff(summary: summary, added: added, removed: removed, othersKept: others, whole: after)
    }

    // MARK: Lines

    static func lines(_ text: String) -> [String] {
        var out = text.components(separatedBy: "\n")
        if out.last == "" { out.removeLast() }
        return out
    }

    /// A JSON object written the way every Koncluí installer writes it; anything else (a plugin) as it is.
    static func canonical(_ text: String) -> String {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let out = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let string = String(data: out, encoding: .utf8) else { return text }
        return string
    }

    /// A line that holds a hook command (`"command"` for Claude Code, Codex, Gemini and Muse, `"bash"` for Copilot).
    static func isCommandLine(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("\"command\"") || t.hasPrefix("\"bash\"")
    }

    static func isKoncluiCommand(_ line: String) -> Bool {
        isCommandLine(line) && line.range(of: "konclui/nb-hook", options: .caseInsensitive) != nil
    }

    private static func orderedLikeFile(_ changed: [String], in file: [String]) -> [String] {
        var remaining = changed
        var out: [String] = []
        for line in file {
            if let i = remaining.firstIndex(of: line) { out.append(line); remaining.remove(at: i) }
        }
        return out + remaining
    }
}
