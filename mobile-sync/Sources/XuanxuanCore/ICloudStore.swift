import Foundation
import CryptoKit


public let xuanxuanAppFolderName = "XuanxuanWritingDemo"

public final class ICloudWritingStore {
    public let rootURL: URL
    public let deviceId: String
    private let fileManager = FileManager.default

    public init(rootURL: URL? = nil, deviceId: String = UUID().uuidString) {
        self.rootURL = rootURL ?? Self.defaultRootURL()
        self.deviceId = deviceId
    }

    public static func defaultRootURL() -> URL {
        if let path = ProcessInfo.processInfo.environment["XUANXUAN_DEMO_ROOT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(xuanxuanAppFolderName, isDirectory: true)
    }

    public var isICloudAvailable: Bool { false }

    public func prepareRoot() throws {
        if rootURL.standardizedFileURL == Self.defaultRootURL().standardizedFileURL {
            try DemoWorkspace.installIfNeeded(at: rootURL)
        }
        try fileManager.createDirectory(at: rootURL.appendingPathComponent("projects", isDirectory: true), withIntermediateDirectories: true)
        let registryURL = rootURL.appendingPathComponent("projects.json")
        if !fileManager.fileExists(atPath: registryURL.path) {
            try JSONEncoder.pretty.encode(ProjectRegistry(projects: [])).write(to: registryURL)
        }
    }

    public func loadProjects() throws -> [WritingProject] {
        try prepareRoot()
        let registryURL = rootURL.appendingPathComponent("projects.json")
        guard fileManager.fileExists(atPath: registryURL.path) else { return [] }
        let registry = try JSONDecoder().decode(ProjectRegistry.self, from: dataContents(of: registryURL))
        let normalized = registry.projects.map(normalizedProject)
        if normalized != registry.projects {
            try JSONEncoder.pretty.encode(ProjectRegistry(projects: normalized)).write(to: registryURL)
            try record(registryURL)
        }
        return normalized.sorted { ($0.lastOpenedAt.isEmpty ? $0.createdAt : $0.lastOpenedAt) > ($1.lastOpenedAt.isEmpty ? $1.createdAt : $1.lastOpenedAt) }
    }

    public func createProject(name: String, description: String = "") throws -> WritingProject {
        try prepareRoot()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = trimmedName.isEmpty ? "新作品" : trimmedName
        let now = ISO8601DateFormatter().string(from: Date())
        let folderName = uniqueFolderName(slug(for: safeName))
        let projectRoot = rootURL
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try fileManager.createDirectory(at: projectRoot.appendingPathComponent("drafts", isDirectory: true), withIntermediateDirectories: true)
        let notes = projectRoot.appendingPathComponent("notes", isDirectory: true)
        try fileManager.createDirectory(at: notes, withIntermediateDirectories: true)
        try ensureDefaultNotes(in: notes)

        let project = WritingProject(
            id: UUID().uuidString,
            name: safeName,
            description: description,
            path: projectRoot.path,
            createdAt: now,
            updatedAt: now,
            lastOpenedAt: now,
            frequencyDays: 1,
            chapterNamePattern: "第%03d章-标题.md"
        )
        var projects = try loadProjects()
        projects.insert(project, at: 0)
        try saveProjects(projects)
        return project
    }

    public func deleteProjectMovingToTrash(_ project: WritingProject) throws {
        let normalized = normalizedProject(project)
        let projectFolder = URL(fileURLWithPath: normalized.path, isDirectory: true)
        guard fileManager.fileExists(atPath: projectFolder.path) else {
            var projects = try loadProjects()
            projects.removeAll { $0.id == project.id }
            try saveProjects(projects)
            return
        }

        var trashedURL: NSURL?
        try fileManager.trashItem(at: projectFolder, resultingItemURL: &trashedURL)
        var projects = try loadProjects()
        projects.removeAll { $0.id == project.id }
        try saveProjects(projects)
    }

    public func listChapters(project: WritingProject) throws -> [MobileChapter] {
        let drafts = projectURL(project).appendingPathComponent("drafts", isDirectory: true)
        guard fileManager.fileExists(atPath: drafts.path) else { return [] }
        try requestICloudDownloads(in: drafts)
        return try fileManager.contentsOfDirectory(at: drafts, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { url in
                let text = try textContents(of: url)
                let parsed = parseMarkdown(text)
                return MobileChapter(fileName: url.lastPathComponent, chapterNumber: parsed.chapterNumber == 0 ? chapterNumber(from: url.lastPathComponent) : parsed.chapterNumber, title: parsed.title, body: parsed.body, wordCount: parsed.body.filter { !$0.isWhitespace }.count, rawFrontmatter: parsed.frontmatter)
            }
    }

    public func saveChapter(_ chapter: MobileChapter, project: WritingProject) throws {
        let url = projectURL(project)
            .appendingPathComponent("drafts", isDirectory: true)
            .appendingPathComponent(chapter.fileName)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupExistingFile(url)
        let markdown = buildMarkdown(title: chapter.title, frontmatter: chapter.rawFrontmatter, body: chapter.body)
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        try record(url)
    }

    public func createChapter(project: WritingProject, title: String = "新章节") throws -> MobileChapter {
        let drafts = projectURL(project).appendingPathComponent("drafts", isDirectory: true)
        try fileManager.createDirectory(at: drafts, withIntermediateDirectories: true)
        let chapterNumber = ((try? listChapters(project: project).count) ?? 0) + 1
        let chapterTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新章节" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = String(format: "第%03d章-%@.md", chapterNumber, sanitizedFileComponent(chapterTitle))
        let chapter = MobileChapter(
            fileName: fileName,
            chapterNumber: chapterNumber,
            title: chapterTitle,
            body: "",
            wordCount: 0,
            rawFrontmatter: """
            title: \(chapterTitle)
            chapter: \(chapterNumber)
            status: drafting
            target_words:
            published: false
            publish_at:
            draft_completed_at:
            published_at:
            """
        )
        try saveChapter(chapter, project: project)
        return chapter
    }

    public func projectSummary(_ project: WritingProject) throws -> ProjectSummary {
        let chapters = try listChapters(project: project)
        return ProjectSummary(chapterCount: chapters.count, totalWords: chapters.reduce(0) { $0 + $1.wordCount })
    }

    public func listRelatedDocs(project: WritingProject) throws -> [RelatedDoc] {
        let notes = projectURL(project).appendingPathComponent("notes", isDirectory: true)
        try fileManager.createDirectory(at: notes, withIntermediateDirectories: true)
        try ensureDefaultNotes(in: notes)
        try requestICloudDownloads(in: notes)
        let defaultFiles: [(String, String)] = [
            ("作品设定.md", "作品设定"),
            ("作品大纲.md", "作品大纲"),
            ("角色设定.md", "角色设定"),
            ("灵感记录.md", "灵感记录")
        ]
        var docs: [RelatedDoc] = []
        for (fileName, category) in defaultFiles {
            let url = notes.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: url.path) {
                let body = try textContents(of: url)
                docs.append(RelatedDoc(title: url.deletingPathExtension().lastPathComponent, category: category, relativePath: "notes/\(fileName)", body: body, fileKind: relatedDocKind(for: url)))
            }
        }
        let directFiles = try fileManager.contentsOfDirectory(at: notes, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        for file in directFiles where file.pathExtension.lowercased() == RelatedDocFileKind.text.rawValue {
            let body = try textContents(of: file)
            docs.append(RelatedDoc(title: file.deletingPathExtension().lastPathComponent, category: "导入资料", relativePath: "notes/\(file.lastPathComponent)", body: body, fileKind: .text))
        }
        let folders = try fileManager.contentsOfDirectory(at: notes, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        for folder in folders {
            let values = try? folder.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let category = folder.lastPathComponent
            let files = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            for file in files where isRelatedDocFile(file) {
                let body = try textContents(of: file)
                docs.append(RelatedDoc(title: file.deletingPathExtension().lastPathComponent, category: category, relativePath: "notes/\(category)/\(file.lastPathComponent)", body: body, fileKind: relatedDocKind(for: file)))
            }
        }
        var seen = Set<String>()
        return docs.filter { seen.insert($0.relativePath).inserted }
    }

    public func saveRelatedDoc(_ doc: RelatedDoc, project: WritingProject) throws {
        let url = projectURL(project).appendingPathComponent(doc.relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupExistingFile(url)
        try doc.body.write(to: url, atomically: true, encoding: .utf8)
        try record(url)
    }

    public func createRelatedDoc(project: WritingProject, title: String, category: String, fileKind: RelatedDocFileKind = .markdown) throws -> RelatedDoc {
        let safeCategory = category.isEmpty ? "灵感记录" : category
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = trimmedTitle.isEmpty ? "新资料" : trimmedTitle
        let folder = projectURL(project)
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent(safeCategory, isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = uniqueRelatedFileName(base: sanitizedFileComponent(safeTitle), extensionName: fileKind.rawValue, in: folder)
        let relativePath = "notes/\(safeCategory)/\(fileName)"
        let body = fileKind == .markdown ? "# \(safeTitle)\n\n" : ""
        let doc = RelatedDoc(title: safeTitle, category: safeCategory, relativePath: relativePath, body: body, fileKind: fileKind)
        try saveRelatedDoc(doc, project: project)
        return doc
    }

    public func warmUpICloudDrive(maxAttempts: Int = 6) async -> Bool {
        for attempt in 0..<maxAttempts {
            try? requestICloudDownloads()
            if hasProjectRegistryOrFolders {
                return true
            }
            let delay = UInt64(450_000_000 + UInt64(attempt) * 250_000_000)
            try? await Task.sleep(nanoseconds: delay)
        }
        return hasProjectRegistryOrFolders
    }

    public func requestICloudDownloads() throws {
        try requestICloudDownload(for: rootURL)
        try requestICloudDownload(for: rootURL.appendingPathComponent("projects.json"))
        try requestICloudDownloads(in: rootURL.appendingPathComponent("projects", isDirectory: true))
    }

    public func refreshManifestForAllFiles() throws {
        let enumerator = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            if file.path.contains("/.xuanxuan-sync/") { continue }
            let values = try? file.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                try record(file)
            }
        }
    }

    private func normalizedProject(_ project: WritingProject) -> WritingProject {
        let oldURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let folderName = oldURL.lastPathComponent.isEmpty ? project.id : oldURL.lastPathComponent
        let newURL = rootURL.appendingPathComponent("projects", isDirectory: true).appendingPathComponent(folderName, isDirectory: true)
        var normalized = project
        normalized.path = newURL.path
        if let cover = project.coverImagePath {
            let coverName = URL(fileURLWithPath: cover).lastPathComponent
            let targetCover = newURL.appendingPathComponent(coverName)
            normalized.coverImagePath = fileManager.fileExists(atPath: targetCover.path) ? targetCover.path : nil
        }
        return normalized
    }

    private func saveProjects(_ projects: [WritingProject]) throws {
        let registryURL = rootURL.appendingPathComponent("projects.json")
        try JSONEncoder.pretty.encode(ProjectRegistry(projects: projects)).write(to: registryURL)
        try record(registryURL)
    }

    private func ensureDefaultNotes(in notes: URL) throws {
        let defaults = [
            "作品设定.md": "# 作品设定\n\n",
            "作品大纲.md": "# 作品大纲\n\n",
            "角色设定.md": "# 角色设定\n\n",
            "灵感记录.md": "# 灵感记录\n\n"
        ]
        for (fileName, body) in defaults {
            let url = notes.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: url.path) {
                try body.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func slug(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let slug = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return slug.isEmpty ? UUID().uuidString : slug
    }

    private func uniqueFolderName(_ base: String) -> String {
        let projects = rootURL.appendingPathComponent("projects", isDirectory: true)
        var candidate = base
        var index = 2
        while fileManager.fileExists(atPath: projects.appendingPathComponent(candidate, isDirectory: true).path) {
            candidate = "\(base)-\(index)"
            index += 1
        }
        return candidate
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "新文件" : cleaned
    }

    private func projectURL(_ project: WritingProject) -> URL {
        normalizedProject(project).pathURL
    }

    private func parseMarkdown(_ text: String) -> (title: String, chapterNumber: Int, body: String, frontmatter: String) {
        guard text.hasPrefix("---"), let end = text.range(of: "\n---", range: text.index(text.startIndex, offsetBy: 3)..<text.endIndex) else {
            return ("未命名章节", 0, text, "")
        }
        let yaml = String(text[text.index(text.startIndex, offsetBy: 3)..<end.lowerBound])
        let title = yaml.split(separator: "\n").first(where: { $0.hasPrefix("title:") })
            .map { String($0.dropFirst("title:".count)).trimmingCharacters(in: .whitespacesAndNewlines) } ?? "未命名章节"
        let chapterNumber = yaml.split(separator: "\n").first(where: { $0.hasPrefix("chapter:") })
            .flatMap { Int(String($0.dropFirst("chapter:".count)).trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let bodyStart = text.index(end.upperBound, offsetBy: 1, limitedBy: text.endIndex) ?? end.upperBound
        return (title, chapterNumber, String(text[bodyStart...]).trimmingCharacters(in: .newlines), yaml)
    }

    private func chapterNumber(from fileName: String) -> Int {
        let digits = fileName
            .dropFirst(fileName.hasPrefix("第") ? 1 : 0)
            .prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    private func buildMarkdown(title: String, frontmatter: String, body: String) -> String {
        var lines = frontmatter.isEmpty ? ["title: \(title)", "status: drafting", "published: false"] : frontmatter.components(separatedBy: .newlines)
        if let index = lines.firstIndex(where: { $0.hasPrefix("title:") }) {
            lines[index] = "title: \(title)"
        } else {
            lines.insert("title: \(title)", at: 0)
        }
        return "---\n\(lines.joined(separator: "\n"))\n---\n\n\(body)"
    }

    private func record(_ url: URL) throws {
        let relative = relativePath(from: rootURL, to: url)
        var manifest = try loadManifest()
        let data = try dataContents(of: url)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        manifest.files[relative] = SyncFileRecord(path: relative, modifiedAt: ISO8601DateFormatter().string(from: Date()), deviceId: deviceId, contentHash: hash)
        manifest.deviceId = deviceId
        manifest.updatedAt = ISO8601DateFormatter().string(from: Date())
        try writeManifest(manifest)
    }

    private func backupExistingFile(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let backup = rootURL
            .appendingPathComponent(".xuanxuan-sync/backups", isDirectory: true)
            .appendingPathComponent(timestamp(), isDirectory: true)
            .appendingPathComponent(relativePath(from: rootURL, to: url))
        try fileManager.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: url, to: backup)
    }

    private func loadManifest() throws -> SyncManifest {
        let url = rootURL.appendingPathComponent(".xuanxuan-sync/manifest.json")
        guard fileManager.fileExists(atPath: url.path) else {
            return SyncManifest(deviceId: deviceId, updatedAt: ISO8601DateFormatter().string(from: Date()), files: [:])
        }
        return try JSONDecoder().decode(SyncManifest.self, from: dataContents(of: url))
    }

    private func writeManifest(_ manifest: SyncManifest) throws {
        let url = rootURL.appendingPathComponent(".xuanxuan-sync/manifest.json")
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.pretty.encode(manifest).write(to: url)
    }

    private var hasProjectRegistryOrFolders: Bool {
        let registry = rootURL.appendingPathComponent("projects.json")
        let projects = rootURL.appendingPathComponent("projects", isDirectory: true)
        if fileManager.fileExists(atPath: registry.path) {
            return true
        }
        guard fileManager.fileExists(atPath: projects.path) else {
            return false
        }
        let contents = (try? fileManager.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return !contents.isEmpty
    }

    private func isRelatedDocFile(_ url: URL) -> Bool {
        RelatedDocFileKind(rawValue: url.pathExtension.lowercased()) != nil
    }

    private func relatedDocKind(for url: URL) -> RelatedDocFileKind {
        RelatedDocFileKind(rawValue: url.pathExtension.lowercased()) ?? .markdown
    }

    private func uniqueRelatedFileName(base: String, extensionName: String, in folder: URL) -> String {
        var candidate = "\(base).\(extensionName)"
        var index = 2
        while fileManager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(index).\(extensionName)"
            index += 1
        }
        return candidate
    }

    private func textContents(of url: URL) throws -> String {
        String(data: try dataContents(of: url), encoding: .utf8) ?? ""
    }

    private func dataContents(of url: URL) throws -> Data {
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                try requestICloudDownload(for: url)
                return try Data(contentsOf: url)
            } catch {
                lastError = error
                if attempt < 3 {
                    Thread.sleep(forTimeInterval: 0.18 + Double(attempt) * 0.16)
                }
            }
        }
        throw lastError ?? CocoaError(.fileReadUnknown)
    }

    private func requestICloudDownloads(in directory: URL) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try requestICloudDownload(for: directory)
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        for file in files {
            try requestICloudDownload(for: file)
        }
    }

    private func requestICloudDownload(for url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        guard values?.isUbiquitousItem == true else { return }
        if values?.ubiquitousItemDownloadingStatus != .current {
            try? fileManager.startDownloadingUbiquitousItem(at: url)
        }
    }

    private func relativePath(from root: URL, to file: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = file.standardizedFileURL.path
        return filePath.hasPrefix(rootPath + "/") ? String(filePath.dropFirst(rootPath.count + 1)) : file.lastPathComponent
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}

private extension WritingProject {
    var pathURL: URL { URL(fileURLWithPath: path, isDirectory: true) }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
