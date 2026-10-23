import Foundation

public struct ProjectRegistry: Codable {
    public var projects: [WritingProject]

    public init(projects: [WritingProject]) {
        self.projects = projects
    }
}

public struct WritingProject: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var description: String
    public var path: String
    public var coverImagePath: String?
    public var createdAt: String
    public var updatedAt: String
    public var lastOpenedAt: String
    public var frequencyDays: Int
    public var chapterNamePattern: String

    public init(id: String, name: String, description: String, path: String, coverImagePath: String? = nil, createdAt: String, updatedAt: String, lastOpenedAt: String, frequencyDays: Int, chapterNamePattern: String) {
        self.id = id
        self.name = name
        self.description = description
        self.path = path
        self.coverImagePath = coverImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.frequencyDays = frequencyDays
        self.chapterNamePattern = chapterNamePattern
    }
}

public struct MobileChapter: Identifiable, Hashable {
    public var id: String { fileName }
    public var fileName: String
    public var chapterNumber: Int
    public var title: String
    public var body: String
    public var wordCount: Int
    public var rawFrontmatter: String

    public init(fileName: String, chapterNumber: Int = 0, title: String, body: String, wordCount: Int, rawFrontmatter: String = "") {
        self.fileName = fileName
        self.chapterNumber = chapterNumber
        self.title = title
        self.body = body
        self.wordCount = wordCount
        self.rawFrontmatter = rawFrontmatter
    }
}

public enum RelatedDocFileKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case markdown = "md"
    case text = "txt"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .text: return "TXT"
        }
    }

    public var badge: String {
        switch self {
        case .markdown: return "MD"
        case .text: return "TXT"
        }
    }
}

public struct RelatedDoc: Identifiable, Hashable {
    public var id: String { relativePath }
    public var title: String
    public var category: String
    public var relativePath: String
    public var body: String
    public var fileKind: RelatedDocFileKind

    public init(title: String, category: String, relativePath: String, body: String, fileKind: RelatedDocFileKind = .markdown) {
        self.title = title
        self.category = category
        self.relativePath = relativePath
        self.body = body
        self.fileKind = fileKind
    }
}

public struct SyncManifest: Codable {
    public var deviceId: String
    public var updatedAt: String
    public var files: [String: SyncFileRecord]

    public init(deviceId: String, updatedAt: String, files: [String: SyncFileRecord]) {
        self.deviceId = deviceId
        self.updatedAt = updatedAt
        self.files = files
    }
}

public struct SyncFileRecord: Codable {
    public var path: String
    public var modifiedAt: String
    public var deviceId: String
    public var contentHash: String

    public init(path: String, modifiedAt: String, deviceId: String, contentHash: String) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.deviceId = deviceId
        self.contentHash = contentHash
    }
}

public struct ProjectSummary: Hashable {
    public var chapterCount: Int
    public var totalWords: Int

    public init(chapterCount: Int = 0, totalWords: Int = 0) {
        self.chapterCount = chapterCount
        self.totalWords = totalWords
    }
}

// Installs only the bundled fictional example, once, in the isolated local root.
enum DemoWorkspace {
    static func installIfNeeded(at root: URL) throws {
        let fm = FileManager.default
        let registry = root.appendingPathComponent("projects.json")
        guard !fm.fileExists(atPath: registry.path) else { return }
        guard let source = Bundle.main.resourceURL?.appendingPathComponent("DemoWorkspace"),
              fm.fileExists(atPath: source.appendingPathComponent("projects.json").path) else { return }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let targetProjects = root.appendingPathComponent("projects")
        try fm.createDirectory(at: targetProjects, withIntermediateDirectories: true)
        let sourceProjects = source.appendingPathComponent("projects")
        for project in try fm.contentsOfDirectory(at: sourceProjects, includingPropertiesForKeys: nil) {
            let target = targetProjects.appendingPathComponent(project.lastPathComponent)
            if !fm.fileExists(atPath: target.path) { try fm.copyItem(at: project, to: target) }
        }
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: source.appendingPathComponent("projects.json"))) as! [String: Any]
        var projects = object["projects"] as! [[String: Any]]
        for i in projects.indices {
            let folder = URL(fileURLWithPath: projects[i]["path"] as! String).lastPathComponent
            projects[i]["path"] = targetProjects.appendingPathComponent(folder).path
        }
        object["projects"] = projects
        try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: registry, options: .atomic)
    }
}
