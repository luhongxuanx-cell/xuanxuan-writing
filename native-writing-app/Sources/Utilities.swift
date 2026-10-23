import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

func parseFrontmatter(_ markdown: String) -> (meta: ChapterMeta, body: String, hasFrontmatter: Bool, keys: Set<String>) {
    let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
    guard normalized.hasPrefix("---\n"), let range = normalized.range(of: "\n---\n", range: normalized.index(normalized.startIndex, offsetBy: 4)..<normalized.endIndex) else {
        return (ChapterMeta(), markdown, false, [])
    }
    let raw = String(normalized[normalized.index(normalized.startIndex, offsetBy: 4)..<range.lowerBound])
    let body = String(normalized[range.upperBound...])
    var meta = ChapterMeta()
    var keys = Set<String>()
    for line in raw.components(separatedBy: "\n") {
        guard let colon = line.firstIndex(of: ":") else { continue }
        let key = line[..<colon].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        keys.insert(key)
        switch key {
        case "title": meta.title = value.unquoted
        case "chapter": meta.chapter = Int(value) ?? 0
        case "status": meta.status = value
        case "target_words": meta.targetWords = Int(value) ?? 0
        case "published": meta.published = value == "true"
        case "publish_at": meta.publishAt = value
        case "draft_completed_at": meta.draftCompletedAt = value
        case "published_at": meta.publishedAt = value
        default: meta.extra[key] = value
        }
    }
    if meta.status == "published" { meta.published = true }
    return (meta, body, true, keys)
}

func buildMarkdown(meta: ChapterMeta, body: String) -> String {
    let lines = [
        "title: \(yamlValue(meta.title))",
        "chapter: \(meta.chapter)",
        "status: \(meta.status)",
        "target_words: \(meta.targetWords == 0 ? "" : String(meta.targetWords))",
        "published: \(meta.published ? "true" : "false")",
        "publish_at: \(meta.publishAt)",
        "draft_completed_at: \(meta.draftCompletedAt)",
        "published_at: \(meta.publishedAt)"
    ]
    return "---\n\(lines.joined(separator: "\n"))\n---\n\n\(body.trimmingCharacters(in: .whitespacesAndNewlines))"
}

func deriveFromFilename(_ fileName: String) -> (chapter: Int, title: String) {
    let pattern = #"^第(\d+)章-(.+)\.md$"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: fileName, range: NSRange(fileName.startIndex..., in: fileName)),
       let chapterRange = Range(match.range(at: 1), in: fileName),
       let titleRange = Range(match.range(at: 2), in: fileName) {
        return (Int(fileName[chapterRange]) ?? 0, String(fileName[titleRange]))
    }
    return (0, fileName.replacingOccurrences(of: ".md", with: ""))
}

func formatParagraphs(_ text: String) -> String {
    let normalized = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\u{3000}", with: " ")
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .joined(separator: "\n")
    let blocks = normalized.components(separatedBy: "\n\n").flatMap { splitBlock($0) }
    return blocks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
}

func splitBlock(_ block: String) -> [String] {
    let lines = block.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    if lines.count > 1 { return lines }
    let text = block.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.count <= 90 { return [text] }
    var pieces: [String] = []
    var buffer = ""
    for char in text {
        buffer.append(char)
        if "。！？；".contains(char), buffer.count >= 42 {
            pieces.append(buffer)
            buffer = ""
        }
    }
    if !buffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pieces.append(buffer) }
    return pieces.isEmpty ? [text] : pieces
}

func textHeight(_ text: String, font: NSFont, width: CGFloat, lineSpacing: CGFloat = 8) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    let rect = (text as NSString).boundingRect(
        with: NSSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font, .paragraphStyle: paragraph]
    )
    return ceil(rect.height) + 4
}

func drawWrapped(_ text: String, font: NSFont, color: NSColor, rect: NSRect, lineSpacing: CGFloat = 8) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = lineSpacing
    (text as NSString).draw(
        with: rect,
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    )
}

func countWords(_ text: String) -> Int {
    text.filter { !$0.isWhitespace }.count
}

func countSelectedWords(in text: String, range: NSRange) -> Int {
    let nsText = text as NSString
    guard range.length > 0, range.location < nsText.length else { return 0 }
    return countWords(nsText.substring(with: clampedRange(range, length: nsText.length)))
}

func paragraphWordCount(in text: String, range: NSRange) -> Int {
    let nsText = text as NSString
    guard nsText.length > 0 else { return 0 }
    let cursor = min(max(range.location, 0), max(nsText.length - 1, 0))
    let paragraphRange = nsText.paragraphRange(for: NSRange(location: cursor, length: 0))
    return countWords(nsText.substring(with: clampedRange(paragraphRange, length: nsText.length)))
}

func editorStats(for text: String, selectedRange: NSRange) -> EditorStats {
    EditorStats(
        totalWords: countWords(text),
        paragraphWords: paragraphWordCount(in: text, range: selectedRange),
        selectedWords: countSelectedWords(in: text, range: selectedRange)
    )
}

func clampedRange(_ range: NSRange, length: Int) -> NSRange {
    let location = min(max(range.location, 0), length)
    let upper = min(max(range.location + range.length, location), length)
    return NSRange(location: location, length: upper - location)
}

func rangesForFind(_ needle: String, in text: String, selectedRange: NSRange? = nil, options: FindReplaceOptions, selectionOnly: Bool = false) -> [NSRange] {
    let nsText = text as NSString
    let nsNeedle = needle as NSString
    guard nsNeedle.length > 0, nsText.length > 0 else { return [] }
    let searchRange: NSRange
    if selectionOnly, let selectedRange, selectedRange.length > 0 {
        searchRange = selectedRange
    } else {
        searchRange = NSRange(location: 0, length: nsText.length)
    }
    var compareOptions: NSString.CompareOptions = []
    if !options.caseSensitive {
        compareOptions.insert(.caseInsensitive)
    }
    var result: [NSRange] = []
    var nextLocation = searchRange.location
    let endLocation = searchRange.location + searchRange.length
    while nextLocation < endLocation {
        let range = NSRange(location: nextLocation, length: endLocation - nextLocation)
        let found = nsText.range(of: needle, options: compareOptions, range: range)
        if found.location == NSNotFound { break }
        if !options.wholeWord || isWholeWordRange(found, in: nsText) {
            result.append(found)
        }
        nextLocation = max(found.location + max(found.length, 1), nextLocation + 1)
    }
    return result
}

func isWholeWordRange(_ range: NSRange, in text: NSString) -> Bool {
    let before = range.location > 0 ? text.substring(with: NSRange(location: range.location - 1, length: 1)).unicodeScalars.first : nil
    let afterLocation = range.location + range.length
    let after = afterLocation < text.length ? text.substring(with: NSRange(location: afterLocation, length: 1)).unicodeScalars.first : nil
    return !isWordScalar(before) && !isWordScalar(after)
}

func isWordScalar(_ scalar: UnicodeScalar?) -> Bool {
    guard let scalar else { return false }
    if CharacterSet.alphanumerics.contains(scalar) { return true }
    return scalar == "_"
}

func slugify(_ text: String) -> String {
    let cleaned = text.lowercased().map { char -> Character in
        if char.isLetter || char.isNumber || String(char).range(of: #"\p{Han}"#, options: .regularExpression) != nil {
            return char
        }
        return "-"
    }
    return String(cleaned).split(separator: "-").joined(separator: "-")
}

func safeFileName(_ text: String) -> String {
    let forbidden = CharacterSet(charactersIn: "/:\\?%*\"<>|")
    let parts = text.components(separatedBy: forbidden).joined(separator: "-")
    return parts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新作品" : parts
}

func uniqueId(base: String, existing: [String]) -> String {
    var candidate = base.isEmpty ? "project" : base
    var index = 2
    let set = Set(existing)
    while set.contains(candidate) {
        candidate = "\(base)-\(index)"
        index += 1
    }
    return candidate
}

func uniqueDirectoryName(base: String, in root: URL) throws -> String {
    var candidate = base
    var index = 2
    while FileManager.default.fileExists(atPath: root.appendingPathComponent(candidate).path) {
        candidate = "\(base)-\(index)"
        index += 1
    }
    return candidate
}

func relativePath(from root: URL, to file: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let filePath = file.standardizedFileURL.path
    if filePath.hasPrefix(rootPath + "/") {
        return String(filePath.dropFirst(rootPath.count + 1))
    }
    return file.lastPathComponent
}

func categoryOrder(_ category: String) -> Int {
    switch category {
    case "作品设定": return 0
    case "作品大纲": return 1
    case "角色设定": return 2
    case "灵感记录": return 3
    case "导入资料": return 4
    default: return 9
    }
}

func relatedFolderName(for category: String) -> String {
    switch category {
    case "作品设定": return "作品设定"
    case "作品大纲": return "作品大纲"
    case "角色设定": return "角色设定"
    case "灵感记录": return "灵感记录"
    case "导入资料": return "导入资料"
    default: return safeFileName(category)
    }
}

func yamlValue(_ text: String) -> String {
    if text.contains(":") || text.contains("#") || text.hasPrefix(" ") || text.hasSuffix(" ") {
        return "\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\""
    }
    return text
}

func isoNow() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func todayString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

func timeNowString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: Date())
}

func fileTimestampString() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
    return formatter.string(from: Date())
}

func dateFromString(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
}

func calendarDays(from start: Date, to end: Date) -> Int {
    Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: end)).day ?? 0
}

func showAlert(_ title: String, _ message: String) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
}

extension String {
    var unquoted: String {
        if (hasPrefix("\"") && hasSuffix("\"")) || (hasPrefix("'") && hasSuffix("'")) {
            return String(dropFirst().dropLast())
        }
        return self
    }
}

extension FileManager {
    func copyItem(at source: URL, to target: URL, replacing: Bool) throws {
        if replacing, fileExists(atPath: target.path) {
            try removeItem(at: target)
        }
        try copyItem(at: source, to: target)
    }
}
