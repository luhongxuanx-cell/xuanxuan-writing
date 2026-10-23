import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct FileService {
    let fileManager = FileManager.default
    let dataRoot: URL
    let projectsRootURL: URL
    let registryFileURL: URL
    let syncEnabled: Bool
    let deviceId: String

    init(settings: AppSettings = .defaults) {
        let requestedRoot: URL
        if settings.syncEnabled {
            if settings.syncRootPath.isEmpty {
                requestedRoot = appSupportRoot
            } else {
                requestedRoot = URL(fileURLWithPath: settings.syncRootPath, isDirectory: true)
            }
        } else {
            requestedRoot = appSupportRoot
        }
        self.dataRoot = requestedRoot
        self.projectsRootURL = requestedRoot.appendingPathComponent("projects", isDirectory: true)
        self.registryFileURL = requestedRoot.appendingPathComponent("projects.json")
        self.syncEnabled = settings.syncEnabled
        self.deviceId = settings.deviceId
    }

    func loadProjects() throws -> [WritingProject] {
        if !syncEnabled { try DemoWorkspace.installIfNeeded(at: dataRoot) }
        try fileManager.createDirectory(at: projectsRootURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: registryFileURL.path) {
            try writeRegistry(ProjectRegistry(projects: []))
        }
        var registry = try readRegistry()
        var changed = false
        registry.projects = registry.projects.map { project in
            var migrated = project
            if let newPath = migratedProjectPath(for: project) {
                migrated.path = newPath.path
                changed = true
            }
            let normalizedCover = normalizedCoverPath(for: migrated)
            if normalizedCover != migrated.coverImagePath {
                migrated.coverImagePath = normalizedCover
                changed = true
            }
            return migrated
        }
        let deduped = deduplicatedProjects(registry.projects)
        if deduped != registry.projects {
            registry.projects = deduped
            changed = true
        }
        var known = Set(registry.projects.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path })
        let projectDirs = (try? fileManager.contentsOfDirectory(at: projectsRootURL, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for dir in projectDirs {
            let values = try? dir.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let drafts = dir.appendingPathComponent("drafts", isDirectory: true)
            guard fileManager.fileExists(atPath: drafts.path) else { continue }
            let normalized = dir.standardizedFileURL.path
            guard !known.contains(normalized) else { continue }
            let name = readProjectName(from: dir)
            registry.projects.append(WritingProject(
                id: uniqueId(base: slugify(dir.lastPathComponent), existing: registry.projects.map(\.id)),
                name: name,
                description: "",
                path: dir.path,
                coverImagePath: nil,
                createdAt: isoNow(),
                updatedAt: isoNow(),
                lastOpenedAt: "",
                frequencyDays: 7,
                chapterNamePattern: "第001章-标题.md"
            ))
            known.insert(normalized)
            changed = true
        }
        if changed { try writeRegistry(registry) }
        return registry.projects.sorted { ($0.lastOpenedAt.isEmpty ? $0.createdAt : $0.lastOpenedAt) > ($1.lastOpenedAt.isEmpty ? $1.createdAt : $1.lastOpenedAt) }
    }

    func loadSettings() throws -> AppSettings {
        try fileManager.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            let defaults = AppSettings.defaults
            try saveSettings(defaults)
            return defaults
        }
        return try JSONDecoder().decode(AppSettings.self, from: Data(contentsOf: settingsURL))
    }

    func saveSettings(_ settings: AppSettings) throws {
        try fileManager.createDirectory(at: appSupportRoot, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: settingsURL)
    }

    func enableICloudSync(settings: AppSettings) throws -> URL {
        let panel = NSOpenPanel()
        panel.title = "选择演示或共享作品根文件夹"
        panel.message = "选择含 projects.json 和 projects 的文件夹；跨设备使用时请选择 iCloud Drive 中的专用文件夹。"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let root = panel.url else {
            throw AppError.message("未选择文件夹，当前数据位置未改变。")
        }
        try fileManager.createDirectory(at: root.appendingPathComponent("projects"), withIntermediateDirectories: true)
        return root
    }

    func createProject(name: String, description: String) throws -> WritingProject {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw AppError.message("作品名不能为空") }
        var registry = try readRegistry()
        let dirName = try uniqueDirectoryName(base: safeFileName(cleanName), in: projectsRootURL)
        let projectURL = projectsRootURL.appendingPathComponent(dirName, isDirectory: true)
        try fileManager.createDirectory(at: projectURL.appendingPathComponent("drafts", isDirectory: true), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: projectURL.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)
        let readme = projectURL.appendingPathComponent("README.md")
        try "# \(cleanName)\n\n\(description)\n".write(to: readme, atomically: true, encoding: .utf8)
        try recordSyncFile(readme)
        let project = WritingProject(
            id: uniqueId(base: slugify(dirName), existing: registry.projects.map(\.id)),
            name: cleanName,
            description: description,
            path: projectURL.path,
            coverImagePath: nil,
            createdAt: isoNow(),
            updatedAt: isoNow(),
            lastOpenedAt: isoNow(),
            frequencyDays: 7,
            chapterNamePattern: "第001章-标题.md"
        )
        registry.projects.append(project)
        try writeRegistry(registry)
        _ = try listRelatedDocs(project: project)
        return project
    }

    func updateProject(_ project: WritingProject) throws {
        var registry = try readRegistry()
        if let index = registry.projects.firstIndex(where: { $0.id == project.id }) {
            registry.projects[index] = project
        } else {
            registry.projects.append(project)
        }
        try writeRegistry(registry)
    }

    func updateProjectDetails(project: WritingProject, name: String, description: String) throws -> WritingProject {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw AppError.message("书名不能为空") }
        var updated = project
        updated.name = cleanName
        updated.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.updatedAt = isoNow()
        try updateProject(updated)
        try updateReadme(project: updated)
        return updated
    }

    func setProjectCover(project: WritingProject, imageURL: URL) throws {
        let ext = imageURL.pathExtension.isEmpty ? "png" : imageURL.pathExtension.lowercased()
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let target = projectURL.appendingPathComponent("cover.\(ext)")
        let sourcePath = imageURL.standardizedFileURL.path
        let targetPath = target.standardizedFileURL.path
        if sourcePath != targetPath {
            for old in try coverFiles(in: projectURL) {
                try? fileManager.removeItem(at: old)
            }
            try fileManager.copyItem(at: imageURL, to: target)
        }
        try recordSyncFile(target)
        var updated = project
        updated.coverImagePath = target.path
        updated.updatedAt = isoNow()
        try updateProject(updated)
    }

    func removeProjectCover(project: WritingProject) throws {
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        for old in try coverFiles(in: projectURL) {
            try? fileManager.removeItem(at: old)
        }
        var updated = project
        updated.coverImagePath = nil
        updated.updatedAt = isoNow()
        try updateProject(updated)
    }

    func listChapters(project: WritingProject) throws -> [Chapter] {
        let drafts = draftsURL(project)
        try fileManager.createDirectory(at: drafts, withIntermediateDirectories: true)
        let files = try fileManager.contentsOfDirectory(at: drafts, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "md" }
        return try files.map { try readChapter(project: project, fileName: $0.lastPathComponent) }
            .sorted {
                if $0.meta.chapter != $1.meta.chapter { return $0.meta.chapter < $1.meta.chapter }
                return $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending
            }
    }

    func readChapter(project: WritingProject, fileName: String) throws -> Chapter {
        let url = draftsURL(project).appendingPathComponent(fileName)
        let markdown = try String(contentsOf: url, encoding: .utf8)
        let parsed = parseFrontmatter(markdown)
        let derived = deriveFromFilename(fileName)
        var meta = parsed.meta
        if meta.title.isEmpty { meta.title = derived.title }
        if meta.chapter == 0 { meta.chapter = derived.chapter }
        let missing = ["title", "chapter", "status", "published", "publish_at"].filter { !parsed.keys.contains($0) }
        return Chapter(fileName: fileName, url: url, hasFrontmatter: parsed.hasFrontmatter, meta: meta, body: parsed.body, wordCount: countWords(parsed.body), missingFields: missing)
    }

    func createChapter(project: WritingProject, title: String) throws -> Chapter {
        let chapters = try listChapters(project: project)
        let next = (chapters.map { $0.meta.chapter }.max() ?? 0) + 1
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新章节" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = "第\(String(format: "%03d", next))章-\(safeFileName(cleanTitle)).md"
        let url = draftsURL(project).appendingPathComponent(fileName)
        guard !fileManager.fileExists(atPath: url.path) else { throw AppError.message("这一章已经存在") }
        let meta = ChapterMeta(title: cleanTitle, chapter: next, status: "drafting", published: false)
        try buildMarkdown(meta: meta, body: "").write(to: url, atomically: true, encoding: .utf8)
        try recordSyncFile(url)
        return try readChapter(project: project, fileName: fileName)
    }

    func deleteChapter(project: WritingProject, chapter: Chapter) throws {
        let url = draftsURL(project).appendingPathComponent(chapter.fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            throw AppError.message("找不到章节文件：\(chapter.fileName)")
        }
        var trashedURL: NSURL?
        try fileManager.trashItem(at: url, resultingItemURL: &trashedURL)
    }

    func createRelatedDoc(project: WritingProject, title: String, category: String, fileKind: RelatedDocKind = .markdown) throws -> RelatedDoc {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "新资料" : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let folder = projectURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent(relatedFolderName(for: category), isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = try uniqueRelatedFileName(base: safeFileName(cleanTitle), extensionName: fileKind.rawValue, in: folder)
        let url = folder.appendingPathComponent(fileName)
        let body = fileKind == .markdown ? "# \(cleanTitle)\n\n" : ""
        try body.write(to: url, atomically: true, encoding: .utf8)
        try recordSyncFile(url)
        return try relatedDoc(url: url, projectURL: projectURL, category: category)
    }

    func importTextDoc(project: WritingProject, sourceURL: URL, category: String = "导入资料") throws -> RelatedDoc {
        guard sourceURL.pathExtension.lowercased() == RelatedDocKind.text.rawValue else {
            throw AppError.message("请选择 txt 文档。")
        }
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let folder = projectURL
            .appendingPathComponent("notes", isDirectory: true)
            .appendingPathComponent(relatedFolderName(for: category), isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let baseName = safeFileName(sourceURL.deletingPathExtension().lastPathComponent)
        let fileName = try uniqueRelatedFileName(base: baseName, extensionName: RelatedDocKind.text.rawValue, in: folder)
        let targetURL = folder.appendingPathComponent(fileName)
        try fileManager.copyItem(at: sourceURL, to: targetURL)
        try recordSyncFile(targetURL)
        return try relatedDoc(url: targetURL, projectURL: projectURL, category: category)
    }

    func listRelatedDocs(project: WritingProject) throws -> [RelatedDoc] {
        try ensureDefaultRelatedDocs(project: project)
        var docs: [RelatedDoc] = []
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let specs: [(String, String)] = [
            ("notes/作品设定.md", "作品设定"),
            ("notes/作品大纲.md", "作品大纲"),
            ("notes/角色设定.md", "角色设定"),
            ("notes/灵感记录.md", "灵感记录")
        ]
        for (relativePath, category) in specs {
            let url = projectURL.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: url.path) {
                docs.append(try relatedDoc(url: url, projectURL: projectURL, category: category))
            }
        }
        let structureFolder = projectURL.appendingPathComponent("structure", isDirectory: true)
        docs.append(contentsOf: try docsInFolder(structureFolder, projectURL: projectURL, category: "作品大纲", including: ["chapter-outline"]))
        docs.append(contentsOf: try docsInFolder(structureFolder, projectURL: projectURL, category: "作品设定", excluding: ["chapter-outline"]))
        docs.append(contentsOf: try docsInFolder(projectURL.appendingPathComponent("scene-cards", isDirectory: true), projectURL: projectURL, category: "作品大纲"))
        docs.append(contentsOf: try docsInFolder(projectURL.appendingPathComponent("characters", isDirectory: true), projectURL: projectURL, category: "角色设定"))
        let notes = projectURL.appendingPathComponent("notes", isDirectory: true)
        docs.append(contentsOf: try docsInFolder(notes, projectURL: projectURL, category: "导入资料", extensions: [RelatedDocKind.text.rawValue]))
        for category in relatedCategories {
            docs.append(contentsOf: try docsInFolder(notes.appendingPathComponent(relatedFolderName(for: category), isDirectory: true), projectURL: projectURL, category: category))
        }
        return uniqueRelatedDocs(docs).sorted {
            if categoryOrder($0.category) != categoryOrder($1.category) {
                return categoryOrder($0.category) < categoryOrder($1.category)
            }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    func readRelatedDoc(project: WritingProject, doc: RelatedDoc) throws -> (doc: RelatedDoc, body: String) {
        let text = try String(contentsOf: doc.url, encoding: .utf8)
        let fresh = try relatedDoc(url: doc.url, projectURL: URL(fileURLWithPath: project.path, isDirectory: true), category: doc.category)
        return (fresh, text)
    }

    func saveRelatedDoc(project: WritingProject, doc: RelatedDoc, body: String) throws {
        try makeSnapshot(project: project, key: "相关/\(doc.relativePath)", source: doc.url)
        try makeSyncBackup(for: doc.url)
        try body.write(to: doc.url, atomically: true, encoding: .utf8)
        try recordSyncFile(doc.url)
    }

    func saveChapter(project: WritingProject, fileName: String, meta: ChapterMeta, body: String) throws {
        let url = draftsURL(project).appendingPathComponent(fileName)
        try makeSnapshot(project: project, key: fileName, source: url)
        try makeSyncBackup(for: url)
        try buildMarkdown(meta: meta, body: body).write(to: url, atomically: true, encoding: .utf8)
        try recordSyncFile(url)
    }

    func exportChapterImage(title: String, body: String, settings: AppSettings, to url: URL) throws {
        let width: CGFloat = 1080
        let horizontal: CGFloat = 96
        let vertical: CGFloat = 88
        let titleFont = NSFont.boldSystemFont(ofSize: 40)
        let bodyFont = NSFont(name: settings.fontName, size: 30) ?? NSFont.systemFont(ofSize: 30)
        let textColor = settings.editorTextNSColor
        let bodyWidth = width - horizontal * 2
        let titleText = title.isEmpty ? "未命名章节" : title
        let paragraphs = body.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let titleHeight = textHeight(titleText, font: titleFont, width: bodyWidth)
        let paragraphHeights = paragraphs.map { textHeight("　　\($0)", font: bodyFont, width: bodyWidth, lineSpacing: 14) }
        let contentHeight = titleHeight + 52 + paragraphHeights.reduce(0, +) + CGFloat(max(0, paragraphs.count - 1)) * 24
        let height = max(1080, contentHeight + vertical * 2)
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        settings.editorBackgroundNSColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        var y = height - vertical
        drawWrapped(titleText, font: titleFont, color: textColor, rect: NSRect(x: horizontal, y: y - titleHeight, width: bodyWidth, height: titleHeight))
        y -= titleHeight + 52
        for (index, paragraph) in paragraphs.enumerated() {
            let text = "　　\(paragraph)"
            let paragraphHeight = paragraphHeights[index]
            drawWrapped(text, font: bodyFont, color: textColor, rect: NSRect(x: horizontal, y: y - paragraphHeight, width: bodyWidth, height: paragraphHeight), lineSpacing: 14)
            y -= paragraphHeight + 24
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            throw AppError.message("图片生成失败")
        }
        try png.write(to: url)
    }

    func listSnapshots(project: WritingProject, key: String) throws -> [Snapshot] {
        let dir = snapshotFolder(project: project, key: key)
        guard fileManager.fileExists(atPath: dir.path) else { return [] }
        return try fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "md" }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                return Snapshot(fileName: url.lastPathComponent, createdAt: date, url: url)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func restoreSnapshot(project: WritingProject, key: String, targetURL: URL, snapshot: Snapshot) throws {
        try fileManager.copyItem(at: snapshot.url, to: targetURL, replacing: true)
    }

    func calculateStats(chapters: [Chapter], frequencyDays: Int) -> ProjectStats {
        let ready = chapters.filter { $0.meta.status == "ready" && !$0.meta.published }
        let scheduled = chapters.filter { $0.meta.status == "scheduled" && !$0.meta.published }
        let unpublished = chapters.filter { !$0.meta.published && $0.meta.status != "published" }
        let published = chapters.filter { $0.meta.published || $0.meta.status == "published" }
        let upcoming = unpublished.filter { !$0.meta.publishAt.isEmpty }.sorted { $0.meta.publishAt < $1.meta.publishAt }.first ?? unpublished.first
        let nextDate = upcoming.flatMap { dateFromString($0.meta.publishAt) }
        var stats = ProjectStats()
        stats.totalChapters = chapters.count
        stats.totalWords = chapters.reduce(0) { $0 + $1.wordCount }
        stats.readyCount = ready.count
        stats.scheduledCount = scheduled.count
        stats.publishedCount = published.count
        stats.supportUpdates = ready.count + scheduled.count
        stats.supportDays = stats.supportUpdates * frequencyDays
        stats.nextChapterId = upcoming?.id ?? ""
        stats.nextChapterTitle = upcoming?.meta.title ?? ""
        stats.nextPublishAt = upcoming?.meta.publishAt ?? ""
        stats.daysUntilNextPublish = nextDate.map { calendarDays(from: Date(), to: $0) }
        stats.missingCount = chapters.filter { !$0.missingFields.isEmpty }.count
        return stats
    }

    private func readRegistry() throws -> ProjectRegistry {
        if !fileManager.fileExists(atPath: registryFileURL.path) {
            try fileManager.createDirectory(at: dataRoot, withIntermediateDirectories: true)
            try writeRegistry(ProjectRegistry(projects: []))
        }
        return try JSONDecoder().decode(ProjectRegistry.self, from: Data(contentsOf: registryFileURL))
    }

    private func writeRegistry(_ registry: ProjectRegistry) throws {
        try fileManager.createDirectory(at: dataRoot, withIntermediateDirectories: true)
        try makeSyncBackup(for: registryFileURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(registry).write(to: registryFileURL)
        try recordSyncFile(registryFileURL)
    }

    private func migratedProjectPath(for project: WritingProject) -> URL? {
        // Registry paths may originate on another device. Always resolve inside the selected root.
        let folder = URL(fileURLWithPath: project.path).lastPathComponent
        let target = projectsRootURL.appendingPathComponent(folder, isDirectory: true)
        return target.path == project.path ? nil : target
    }

    private func deduplicatedProjects(_ projects: [WritingProject]) -> [WritingProject] {
        var byPath: [String: WritingProject] = [:]
        for project in projects {
            let key = URL(fileURLWithPath: project.path, isDirectory: true).standardizedFileURL.path
            if let existing = byPath[key] {
                byPath[key] = preferredProject(existing, project)
            } else {
                byPath[key] = project
            }
        }
        return Array(byPath.values)
    }

    private func preferredProject(_ lhs: WritingProject, _ rhs: WritingProject) -> WritingProject {
        let lhsHasCover = lhs.coverImagePath?.isEmpty == false
        let rhsHasCover = rhs.coverImagePath?.isEmpty == false
        if lhsHasCover != rhsHasCover { return lhsHasCover ? lhs : rhs }
        let lhsDate = lhs.lastOpenedAt.isEmpty ? lhs.updatedAt : lhs.lastOpenedAt
        let rhsDate = rhs.lastOpenedAt.isEmpty ? rhs.updatedAt : rhs.lastOpenedAt
        return lhsDate >= rhsDate ? lhs : rhs
    }

    private func readProjectName(from url: URL) -> String {
        let readme = url.appendingPathComponent("README.md")
        guard let text = try? String(contentsOf: readme, encoding: .utf8) else { return url.lastPathComponent }
        return text.split(separator: "\n").first(where: { $0.hasPrefix("# ") }).map { String($0.dropFirst(2)) } ?? url.lastPathComponent
    }

    private func updateReadme(project: WritingProject) throws {
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let readme = projectURL.appendingPathComponent("README.md")
        let existing = (try? String(contentsOf: readme, encoding: .utf8)) ?? ""
        let lines = existing.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let body: String
        if let firstTitle = lines.firstIndex(where: { $0.hasPrefix("# ") }) {
            var updatedLines = lines
            updatedLines[firstTitle] = "# \(project.name)"
            body = updatedLines.joined(separator: "\n")
        } else {
            let suffix = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            body = suffix.isEmpty ? "# \(project.name)\n\n\(project.description)\n" : "# \(project.name)\n\n\(suffix)\n"
        }
        try makeSyncBackup(for: readme)
        try body.write(to: readme, atomically: true, encoding: .utf8)
        try recordSyncFile(readme)
    }

    private func normalizedCoverPath(for project: WritingProject) -> String? {
        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        return (try? coverFiles(in: projectURL).first)?.path
    }

    private func coverFiles(in projectURL: URL) throws -> [URL] {
        let names = ["cover.png", "cover.jpg", "cover.jpeg", "cover.heic"]
        return names.map { projectURL.appendingPathComponent($0) }.filter { fileManager.fileExists(atPath: $0.path) }
    }

    private func draftsURL(_ project: WritingProject) -> URL {
        URL(fileURLWithPath: project.path, isDirectory: true).appendingPathComponent("drafts", isDirectory: true)
    }

    private func snapshotsURL(_ project: WritingProject) -> URL {
        URL(fileURLWithPath: project.path, isDirectory: true).appendingPathComponent(".writing-app-snapshots", isDirectory: true)
    }

    private func makeSnapshot(project: WritingProject, key: String, source: URL) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        let folder = snapshotFolder(project: project, key: key)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: folder.appendingPathComponent("latest.md"), replacing: true)
    }

    private func snapshotFolder(project: WritingProject, key: String) -> URL {
        let safeKey = key.replacingOccurrences(of: ".md", with: "").components(separatedBy: CharacterSet(charactersIn: "/:\\?%*\"<>|")).joined(separator: "-")
        return snapshotsURL(project).appendingPathComponent(safeKey, isDirectory: true)
    }

    private func ensureDefaultRelatedDocs(project: WritingProject) throws {
        let notes = URL(fileURLWithPath: project.path, isDirectory: true).appendingPathComponent("notes", isDirectory: true)
        try fileManager.createDirectory(at: notes, withIntermediateDirectories: true)
        let defaults = [
            ("作品设定.md", "# 作品设定\n\n"),
            ("作品大纲.md", "# 作品大纲\n\n"),
            ("角色设定.md", "# 角色设定\n\n"),
            ("灵感记录.md", "# 灵感记录\n\n")
        ]
        for (fileName, content) in defaults {
            let url = notes.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: url.path) {
                try content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func refreshManifestForAllFiles() throws {
        guard syncEnabled else { return }
        try fileManager.createDirectory(at: syncDirectoryURL(), withIntermediateDirectories: true)
        let enumerator = fileManager.enumerator(at: dataRoot, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            if file.path.contains("/.xuanxuan-sync/") { continue }
            let values = try? file.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            try recordSyncFile(file)
        }
    }

    private func recordSyncFile(_ url: URL) throws {
        guard syncEnabled, fileManager.fileExists(atPath: url.path), !url.path.contains("/.xuanxuan-sync/") else { return }
        let relative = relativePath(from: dataRoot, to: url)
        var manifest = try loadSyncManifest()
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        manifest.files[relative] = SyncFileRecord(
            path: relative,
            modifiedAt: isoNow(),
            deviceId: deviceId,
            contentHash: digest
        )
        manifest.deviceId = deviceId
        manifest.updatedAt = isoNow()
        try writeSyncManifest(manifest)
    }

    private func makeSyncBackup(for url: URL) throws {
        guard syncEnabled, fileManager.fileExists(atPath: url.path), !url.path.contains("/.xuanxuan-sync/") else { return }
        let relative = relativePath(from: dataRoot, to: url)
        let timestamp = fileTimestampString()
        let backupURL = syncDirectoryURL()
            .appendingPathComponent("backups", isDirectory: true)
            .appendingPathComponent(timestamp, isDirectory: true)
            .appendingPathComponent(relative)
        try fileManager.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? fileManager.removeItem(at: backupURL)
        try fileManager.copyItem(at: url, to: backupURL)
    }

    private func loadSyncManifest() throws -> SyncManifest {
        let url = manifestURL()
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: url.path) else {
            return SyncManifest(deviceId: deviceId, updatedAt: isoNow(), files: [:])
        }
        return try JSONDecoder().decode(SyncManifest.self, from: Data(contentsOf: url))
    }

    private func writeSyncManifest(_ manifest: SyncManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try fileManager.createDirectory(at: manifestURL().deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(manifest).write(to: manifestURL())
    }

    private func syncDirectoryURL() -> URL {
        dataRoot.appendingPathComponent(".xuanxuan-sync", isDirectory: true)
    }

    private func manifestURL() -> URL {
        syncDirectoryURL().appendingPathComponent("manifest.json")
    }

    private func docsInFolder(_ folder: URL, projectURL: URL, category: String, including: [String] = [], excluding: [String] = [], extensions: [String] = RelatedDocKind.allCases.map(\.rawValue)) throws -> [RelatedDoc] {
        guard fileManager.fileExists(atPath: folder.path) else { return [] }
        let allowedExtensions = Set(extensions.map { $0.lowercased() })
        return try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { url in
                allowedExtensions.contains(url.pathExtension.lowercased())
                    && (including.isEmpty || including.contains(where: { included in url.lastPathComponent.contains(included) }))
                    && !excluding.contains(where: { excluded in url.lastPathComponent.contains(excluded) })
            }
            .map { try relatedDoc(url: $0, projectURL: projectURL, category: category) }
    }

    private func relatedDoc(url: URL, projectURL: URL, category: String) throws -> RelatedDoc {
        let text = try String(contentsOf: url, encoding: .utf8)
        let relative = relativePath(from: projectURL, to: url)
        return RelatedDoc(
            title: url.deletingPathExtension().lastPathComponent,
            category: category,
            url: url,
            relativePath: relative,
            wordCount: countWords(text),
            fileKind: RelatedDocKind(rawValue: url.pathExtension.lowercased()) ?? .markdown
        )
    }

    private func uniqueRelatedDocs(_ docs: [RelatedDoc]) -> [RelatedDoc] {
        var seen = Set<String>()
        return docs.filter { doc in
            if seen.contains(doc.relativePath) { return false }
            seen.insert(doc.relativePath)
            return true
        }
    }

    private func uniqueRelatedFileName(base: String, extensionName: String, in folder: URL) throws -> String {
        var candidate = "\(base).\(extensionName)"
        var index = 2
        while fileManager.fileExists(atPath: folder.appendingPathComponent(candidate).path) {
            candidate = "\(base)-\(index).\(extensionName)"
            index += 1
        }
        return candidate
    }
}
