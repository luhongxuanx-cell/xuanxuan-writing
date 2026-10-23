import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

let appDisplayName = "萱萱写作 · 演示"
let appSupportRoot: URL = {
    if let path = ProcessInfo.processInfo.environment["XUANXUAN_DEMO_ROOT"], !path.isEmpty {
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("XuanxuanWritingDemo", isDirectory: true)
}()
let projectsRoot = appSupportRoot.appendingPathComponent("projects", isDirectory: true)
let registryURL = appSupportRoot.appendingPathComponent("projects.json")
let settingsURL = appSupportRoot.appendingPathComponent("settings.json")

let statuses = ["planned", "drafting", "revising", "ready", "scheduled", "published"]
let statusLabels = [
    "planned": "已排期",
    "drafting": "正在写",
    "revising": "待修",
    "ready": "可发布",
    "scheduled": "已定时",
    "published": "已发布"
]
let relatedCategories = ["作品设定", "作品大纲", "角色设定", "灵感记录", "导入资料"]

struct ProjectRegistry: Codable {
    var projects: [WritingProject]
}

struct WritingProject: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var path: String
    var coverImagePath: String?
    var createdAt: String
    var updatedAt: String
    var lastOpenedAt: String
    var frequencyDays: Int
    var chapterNamePattern: String
}

struct ChapterMeta: Equatable {
    var title: String = ""
    var chapter: Int = 0
    var status: String = ""
    var targetWords: Int = 0
    var published: Bool = false
    var publishAt: String = ""
    var draftCompletedAt: String = ""
    var publishedAt: String = ""
    var extra: [String: String] = [:]
}

struct Chapter: Identifiable, Equatable {
    var id: String { fileName }
    var fileName: String
    var url: URL
    var hasFrontmatter: Bool
    var meta: ChapterMeta
    var body: String
    var wordCount: Int
    var missingFields: [String]
}

enum RelatedDocKind: String, CaseIterable, Identifiable, Equatable {
    case markdown = "md"
    case text = "txt"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: return "Markdown"
        case .text: return "TXT"
        }
    }

    var badge: String {
        switch self {
        case .markdown: return "MD"
        case .text: return "TXT"
        }
    }
}

struct RelatedDoc: Identifiable, Equatable {
    var id: String { relativePath }
    var title: String
    var category: String
    var url: URL
    var relativePath: String
    var wordCount: Int
    var fileKind: RelatedDocKind
}

enum EditorTarget: Equatable {
    case none
    case chapter
    case related
}

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case writing
    case organizing
    case referencing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .writing: return "写作"
        case .organizing: return "整理"
        case .referencing: return "参照"
        }
    }
}

struct ProjectStats {
    var totalChapters = 0
    var totalWords = 0
    var readyCount = 0
    var scheduledCount = 0
    var publishedCount = 0
    var supportUpdates = 0
    var supportDays = 0
    var nextChapterId = ""
    var nextChapterTitle = ""
    var nextPublishAt = ""
    var daysUntilNextPublish: Int? = nil
    var missingCount = 0
}

struct EditorStats: Equatable {
    var totalWords: Int = 0
    var paragraphWords: Int = 0
    var selectedWords: Int = 0
}

struct Snapshot: Identifiable {
    var id: String { fileName }
    var fileName: String
    var createdAt: Date
    var url: URL
}

struct WritingTheme: Identifiable, Equatable {
    var id: String
    var name: String
    var background: NSColor
    var text: NSColor
    var appBackground: NSColor
    var sidebarBackground: NSColor
    var panelBackground: NSColor
    var cardBackground: NSColor
    var border: NSColor
    var accent: NSColor
    var primaryText: NSColor
    var secondaryText: NSColor
    var mutedText: NSColor
    var inputBackground: NSColor
    var selectedBackground: NSColor

    var backgroundColor: Color { Color(nsColor: background) }
    var textColor: Color { Color(nsColor: text) }
    var appBackgroundColor: Color { Color(nsColor: appBackground) }
    var sidebarBackgroundColor: Color { Color(nsColor: sidebarBackground) }
    var panelBackgroundColor: Color { Color(nsColor: panelBackground) }
    var cardBackgroundColor: Color { Color(nsColor: cardBackground) }
    var borderColor: Color { Color(nsColor: border) }
    var accentColor: Color { Color(nsColor: accent) }
    var primaryTextColor: Color { Color(nsColor: primaryText) }
    var secondaryTextColor: Color { Color(nsColor: secondaryText) }
    var mutedTextColor: Color { Color(nsColor: mutedText) }
    var inputBackgroundColor: Color { Color(nsColor: inputBackground) }
    var selectedBackgroundColor: Color { Color(nsColor: selectedBackground) }
}

let writingThemes = [
    WritingTheme(id: "sujian", name: "素笺", background: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), text: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1), appBackground: NSColor(srgbRed: 0.965, green: 0.953, blue: 0.925, alpha: 1), sidebarBackground: NSColor(srgbRed: 0.925, green: 0.908, blue: 0.86, alpha: 1), panelBackground: NSColor(srgbRed: 0.945, green: 0.933, blue: 0.90, alpha: 1), cardBackground: NSColor(srgbRed: 1.0, green: 0.992, blue: 0.972, alpha: 1), border: NSColor(srgbRed: 0.86, green: 0.84, blue: 0.79, alpha: 1), accent: NSColor(srgbRed: 0.184, green: 0.435, blue: 0.45, alpha: 1), primaryText: NSColor(srgbRed: 0.12, green: 0.10, blue: 0.08, alpha: 1), secondaryText: NSColor(srgbRed: 0.40, green: 0.36, blue: 0.30, alpha: 1), mutedText: NSColor(srgbRed: 0.56, green: 0.52, blue: 0.45, alpha: 1), inputBackground: NSColor(srgbRed: 1.0, green: 0.995, blue: 0.98, alpha: 1), selectedBackground: NSColor(srgbRed: 0.88, green: 0.96, blue: 0.96, alpha: 1)),
    WritingTheme(id: "xingjian", name: "杏笺", background: NSColor(srgbRed: 1.00, green: 0.96, blue: 0.86, alpha: 1), text: NSColor(srgbRed: 0.13, green: 0.11, blue: 0.08, alpha: 1), appBackground: NSColor(srgbRed: 0.965, green: 0.925, blue: 0.82, alpha: 1), sidebarBackground: NSColor(srgbRed: 0.93, green: 0.875, blue: 0.75, alpha: 1), panelBackground: NSColor(srgbRed: 0.95, green: 0.90, blue: 0.79, alpha: 1), cardBackground: NSColor(srgbRed: 1.0, green: 0.965, blue: 0.875, alpha: 1), border: NSColor(srgbRed: 0.84, green: 0.75, blue: 0.61, alpha: 1), accent: NSColor(srgbRed: 0.56, green: 0.34, blue: 0.16, alpha: 1), primaryText: NSColor(srgbRed: 0.16, green: 0.11, blue: 0.06, alpha: 1), secondaryText: NSColor(srgbRed: 0.44, green: 0.31, blue: 0.18, alpha: 1), mutedText: NSColor(srgbRed: 0.60, green: 0.48, blue: 0.34, alpha: 1), inputBackground: NSColor(srgbRed: 1.0, green: 0.975, blue: 0.90, alpha: 1), selectedBackground: NSColor(srgbRed: 0.93, green: 0.80, blue: 0.62, alpha: 1)),
    WritingTheme(id: "zhuqing", name: "竹青", background: NSColor(srgbRed: 0.91, green: 0.97, blue: 0.93, alpha: 1), text: NSColor(srgbRed: 0.08, green: 0.16, blue: 0.12, alpha: 1), appBackground: NSColor(srgbRed: 0.895, green: 0.945, blue: 0.91, alpha: 1), sidebarBackground: NSColor(srgbRed: 0.82, green: 0.90, blue: 0.85, alpha: 1), panelBackground: NSColor(srgbRed: 0.86, green: 0.925, blue: 0.885, alpha: 1), cardBackground: NSColor(srgbRed: 0.95, green: 0.985, blue: 0.955, alpha: 1), border: NSColor(srgbRed: 0.70, green: 0.80, blue: 0.73, alpha: 1), accent: NSColor(srgbRed: 0.16, green: 0.42, blue: 0.31, alpha: 1), primaryText: NSColor(srgbRed: 0.06, green: 0.16, blue: 0.11, alpha: 1), secondaryText: NSColor(srgbRed: 0.23, green: 0.42, blue: 0.32, alpha: 1), mutedText: NSColor(srgbRed: 0.43, green: 0.58, blue: 0.48, alpha: 1), inputBackground: NSColor(srgbRed: 0.96, green: 0.99, blue: 0.97, alpha: 1), selectedBackground: NSColor(srgbRed: 0.78, green: 0.90, blue: 0.83, alpha: 1)),
    WritingTheme(id: "xuanye", name: "玄夜", background: NSColor(srgbRed: 0.04, green: 0.04, blue: 0.05, alpha: 1), text: NSColor(srgbRed: 0.92, green: 0.92, blue: 0.90, alpha: 1), appBackground: NSColor(srgbRed: 0.055, green: 0.060, blue: 0.075, alpha: 1), sidebarBackground: NSColor(srgbRed: 0.075, green: 0.083, blue: 0.105, alpha: 1), panelBackground: NSColor(srgbRed: 0.070, green: 0.077, blue: 0.095, alpha: 1), cardBackground: NSColor(srgbRed: 0.12, green: 0.13, blue: 0.16, alpha: 1), border: NSColor(srgbRed: 0.34, green: 0.38, blue: 0.46, alpha: 1), accent: NSColor(srgbRed: 0.52, green: 0.70, blue: 0.92, alpha: 1), primaryText: NSColor(srgbRed: 0.94, green: 0.96, blue: 0.99, alpha: 1), secondaryText: NSColor(srgbRed: 0.70, green: 0.76, blue: 0.86, alpha: 1), mutedText: NSColor(srgbRed: 0.55, green: 0.60, blue: 0.70, alpha: 1), inputBackground: NSColor(srgbRed: 0.14, green: 0.15, blue: 0.18, alpha: 1), selectedBackground: NSColor(srgbRed: 0.18, green: 0.30, blue: 0.48, alpha: 1)),
    WritingTheme(id: "canghai", name: "藏海", background: NSColor(srgbRed: 0.05, green: 0.10, blue: 0.20, alpha: 1), text: NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1), appBackground: NSColor(srgbRed: 0.045, green: 0.085, blue: 0.145, alpha: 1), sidebarBackground: NSColor(srgbRed: 0.060, green: 0.115, blue: 0.195, alpha: 1), panelBackground: NSColor(srgbRed: 0.055, green: 0.105, blue: 0.175, alpha: 1), cardBackground: NSColor(srgbRed: 0.095, green: 0.17, blue: 0.28, alpha: 1), border: NSColor(srgbRed: 0.30, green: 0.42, blue: 0.58, alpha: 1), accent: NSColor(srgbRed: 0.56, green: 0.75, blue: 1.0, alpha: 1), primaryText: NSColor(srgbRed: 0.94, green: 0.97, blue: 1.0, alpha: 1), secondaryText: NSColor(srgbRed: 0.72, green: 0.80, blue: 0.92, alpha: 1), mutedText: NSColor(srgbRed: 0.56, green: 0.65, blue: 0.78, alpha: 1), inputBackground: NSColor(srgbRed: 0.11, green: 0.20, blue: 0.32, alpha: 1), selectedBackground: NSColor(srgbRed: 0.16, green: 0.31, blue: 0.52, alpha: 1))
]

struct AppSettings: Codable, Equatable {
    var themeId: String = "sujian"
    var fontName: String = "Songti SC"
    var fontSize: Double = 19
    var sidebarVisible: Bool = true
    var detailVisible: Bool = false
    var sidebarWidth: Double = 240
    var detailWidth: Double = 280
    var drawerWidth: Double = 460
    var syncEnabled: Bool = false
    var syncRootPath: String = ""
    var deviceId: String = UUID().uuidString
    var lastSyncAt: String = ""
    var phonePreviewFontSize: Double = 18
    var phonePreviewHorizontalPadding: Double = 34
    var phonePreviewLineSpacing: Double = 10

    static let defaults = AppSettings()

    var theme: WritingTheme { writingThemes.first(where: { $0.id == themeId }) ?? writingThemes[0] }
    var editorBackgroundColor: Color { theme.backgroundColor }
    var editorTextColor: Color { theme.textColor }
    var editorBackgroundNSColor: NSColor { theme.background }
    var editorTextNSColor: NSColor { theme.text }
    var appBackgroundColor: Color { theme.appBackgroundColor }
    var sidebarBackgroundColor: Color { theme.sidebarBackgroundColor }
    var panelBackgroundColor: Color { theme.panelBackgroundColor }
    var cardBackgroundColor: Color { theme.cardBackgroundColor }
    var borderColor: Color { theme.borderColor }
    var accentColor: Color { theme.accentColor }
    var primaryTextColor: Color { theme.primaryTextColor }
    var secondaryTextColor: Color { theme.secondaryTextColor }
    var mutedTextColor: Color { theme.mutedTextColor }
    var inputBackgroundColor: Color { theme.inputBackgroundColor }
    var selectedBackgroundColor: Color { theme.selectedBackgroundColor }

    enum CodingKeys: String, CodingKey {
        case themeId, fontName, fontSize, sidebarVisible, detailVisible, sidebarWidth, detailWidth, drawerWidth
        case syncEnabled, syncRootPath, deviceId, lastSyncAt, phonePreviewFontSize, phonePreviewHorizontalPadding, phonePreviewLineSpacing
        case editorBackgroundRed, editorBackgroundGreen, editorBackgroundBlue
    }

    var editorFont: NSFont {
        NSFont(name: fontName, size: CGFloat(fontSize)) ?? NSFont.systemFont(ofSize: CGFloat(fontSize))
    }

    init(themeId: String = "sujian", fontName: String = "Songti SC", fontSize: Double = 19, sidebarVisible: Bool = true, detailVisible: Bool = false, sidebarWidth: Double = 240, detailWidth: Double = 280, drawerWidth: Double = 460, syncEnabled: Bool = false, syncRootPath: String = "", deviceId: String = UUID().uuidString, lastSyncAt: String = "", phonePreviewFontSize: Double = 18, phonePreviewHorizontalPadding: Double = 34, phonePreviewLineSpacing: Double = 10) {
        self.themeId = themeId
        self.fontName = fontName
        self.fontSize = fontSize
        self.sidebarVisible = sidebarVisible
        self.detailVisible = detailVisible
        self.sidebarWidth = sidebarWidth
        self.detailWidth = detailWidth
        self.drawerWidth = drawerWidth
        self.syncEnabled = syncEnabled
        self.syncRootPath = syncRootPath
        self.deviceId = deviceId
        self.lastSyncAt = lastSyncAt
        self.phonePreviewFontSize = phonePreviewFontSize
        self.phonePreviewHorizontalPadding = phonePreviewHorizontalPadding
        self.phonePreviewLineSpacing = phonePreviewLineSpacing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.themeId = try container.decodeIfPresent(String.self, forKey: .themeId) ?? "sujian"
        self.fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? "Songti SC"
        self.fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 19
        self.sidebarVisible = try container.decodeIfPresent(Bool.self, forKey: .sidebarVisible) ?? true
        self.detailVisible = try container.decodeIfPresent(Bool.self, forKey: .detailVisible) ?? false
        self.sidebarWidth = try container.decodeIfPresent(Double.self, forKey: .sidebarWidth) ?? 240
        self.detailWidth = try container.decodeIfPresent(Double.self, forKey: .detailWidth) ?? 280
        self.drawerWidth = try container.decodeIfPresent(Double.self, forKey: .drawerWidth) ?? 460
        self.syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
        self.syncRootPath = try container.decodeIfPresent(String.self, forKey: .syncRootPath) ?? ""
        self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId) ?? UUID().uuidString
        self.lastSyncAt = try container.decodeIfPresent(String.self, forKey: .lastSyncAt) ?? ""
        self.phonePreviewFontSize = try container.decodeIfPresent(Double.self, forKey: .phonePreviewFontSize) ?? 18
        self.phonePreviewHorizontalPadding = try container.decodeIfPresent(Double.self, forKey: .phonePreviewHorizontalPadding) ?? 34
        self.phonePreviewLineSpacing = try container.decodeIfPresent(Double.self, forKey: .phonePreviewLineSpacing) ?? 10
        if !writingThemes.contains(where: { $0.id == themeId }) {
            self.themeId = "sujian"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(themeId, forKey: .themeId)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(sidebarVisible, forKey: .sidebarVisible)
        try container.encode(detailVisible, forKey: .detailVisible)
        try container.encode(sidebarWidth, forKey: .sidebarWidth)
        try container.encode(detailWidth, forKey: .detailWidth)
        try container.encode(drawerWidth, forKey: .drawerWidth)
        try container.encode(syncEnabled, forKey: .syncEnabled)
        try container.encode(syncRootPath, forKey: .syncRootPath)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(lastSyncAt, forKey: .lastSyncAt)
        try container.encode(phonePreviewFontSize, forKey: .phonePreviewFontSize)
        try container.encode(phonePreviewHorizontalPadding, forKey: .phonePreviewHorizontalPadding)
        try container.encode(phonePreviewLineSpacing, forKey: .phonePreviewLineSpacing)
    }
}

struct SyncManifest: Codable {
    var deviceId: String
    var updatedAt: String
    var files: [String: SyncFileRecord] = [:]
}

struct SyncFileRecord: Codable {
    var path: String
    var modifiedAt: String
    var deviceId: String
    var contentHash: String
}

enum ReferenceDrawer: Equatable {
    case none
    case relatedDoc
}

enum FindReplaceAction: Equatable {
    case findNext
    case findPrevious
    case replaceCurrent
    case replaceAll
    case replaceSelection
}

struct FindReplaceOptions: Equatable {
    var caseSensitive = false
    var wholeWord = false
}

struct FindReplaceRequest: Equatable {
    var id = UUID()
    var action: FindReplaceAction = .findNext
    var find = ""
    var replacement = ""
    var options = FindReplaceOptions()
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
