import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

final class EditorBuffer {
    var text = ""
}

final class AppStore: ObservableObject {
    @Published var projects: [WritingProject] = []
    @Published var selectedProject: WritingProject?
    @Published var chapters: [Chapter] = []
    @Published var relatedDocs: [RelatedDoc] = []
    @Published var referenceDrawer: ReferenceDrawer = .none
    @Published var referenceRelatedDoc: RelatedDoc?
    @Published var referenceRelatedBody = ""
    @Published var selectedChapter: Chapter?
    @Published var selectedRelatedDoc: RelatedDoc?
    @Published var editorTarget: EditorTarget = .none
    @Published var stats = ProjectStats()
    @Published var snapshots: [Snapshot] = []
    @Published var editorTitle = ""
    @Published var editorBody = ""
    @Published var editorStatus = "drafting"
    @Published var editorPublishAt = ""
    @Published var editorTargetWords = ""
    @Published var editorPublished = false
    @Published var editorLiveWordCount = 0
    @Published var currentParagraphWordCount = 0
    @Published var selectedWordCount = 0
    @Published var saveState = "未保存"
    @Published var lastSavedAt = ""
    @Published var showingPhonePreview = false
    @Published var showingNewProject = false
    @Published var showingEditProject = false
    @Published var showingSyncSettings = false
    @Published var editingProject: WritingProject?
    @Published var showingChapterNavigator = false
    @Published var showingNewChapter = false
    @Published var showingNewRelatedDoc = false
    @Published var showingCommandPalette = false
    @Published var formatRequest = UUID()
    @Published var textRequest = UUID()
    @Published var proofreadRequest = UUID()
    @Published var findReplaceRequest = FindReplaceRequest()
    @Published var showingFindReplace = false
    @Published var settings = AppSettings.defaults
    @Published var syncState = "本机已保存"
    @Published var workspaceMode: WorkspaceMode = .writing

    let editorBuffer = EditorBuffer()
    private var loading = false
    private var lastSavedBody = ""
    private var lastSavedMeta: ChapterMeta?
    private var service = FileService()

    func boot() {
        do {
            settings = try service.loadSettings()
            service = FileService(settings: settings)
            syncState = settings.syncEnabled ? "等待 iCloud" : "本机已保存"
            projects = try service.loadProjects()
        } catch {
            saveState = "读取失败"
            showAlert("启动失败", error.localizedDescription)
        }
    }

    func reloadBookshelf() {
        do {
            projects = try service.loadProjects()
        } catch {
            showAlert("刷新失败", error.localizedDescription)
        }
    }

    func chooseCover(for project: WritingProject) {
        let panel = NSOpenPanel()
        panel.title = "选择作品封面"
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.service.setProjectCover(project: project, imageURL: url)
                self.reloadBookshelf()
            } catch {
                showAlert("设置封面失败", error.localizedDescription)
            }
        }
    }

    func removeCover(for project: WritingProject) {
        do {
            try service.removeProjectCover(project: project)
            reloadBookshelf()
        } catch {
            showAlert("移除封面失败", error.localizedDescription)
        }
    }

    func beginEditProject(_ project: WritingProject) {
        editingProject = project
        showingEditProject = true
    }

    func updateProjectDetails(name: String, description: String) {
        guard let project = editingProject else { return }
        do {
            let updated = try service.updateProjectDetails(project: project, name: name, description: description)
            showingEditProject = false
            editingProject = nil
            projects = try service.loadProjects()
            if selectedProject?.id == updated.id {
                selectedProject = updated
            }
        } catch {
            showAlert("修改书名失败", error.localizedDescription)
        }
    }

    func openProject(_ project: WritingProject) {
        do {
            loading = true
            var opened = project
            opened.lastOpenedAt = isoNow()
            try service.updateProject(opened)
            selectedProject = opened
            workspaceMode = .writing
            referenceDrawer = .none
            projects = try service.loadProjects()
            chapters = try service.listChapters(project: opened)
            relatedDocs = try service.listRelatedDocs(project: opened)
            stats = service.calculateStats(chapters: chapters, frequencyDays: opened.frequencyDays)
            if let next = chapters.first(where: { $0.id == stats.nextChapterId }) ?? chapters.first {
                selectChapter(next)
            } else if let doc = relatedDocs.first {
                selectRelatedDoc(doc)
            } else {
                clearEditor()
            }
            loading = false
        } catch {
            loading = false
            showAlert("打开作品失败", error.localizedDescription)
        }
    }

    func backToShelf() {
        saveNow()
        selectedProject = nil
        selectedChapter = nil
        selectedRelatedDoc = nil
        editorTarget = .none
        chapters = []
        relatedDocs = []
        referenceDrawer = .none
        snapshots = []
        reloadBookshelf()
    }

    func createProject(name: String, description: String) {
        do {
            let project = try service.createProject(name: name, description: description)
            projects = try service.loadProjects()
            openProject(project)
        } catch {
            showAlert("新建作品失败", error.localizedDescription)
        }
    }

    func createChapter(title: String) {
        guard let project = selectedProject else { return }
        do {
            let chapter = try service.createChapter(project: project, title: title)
            chapters = try service.listChapters(project: project)
            stats = service.calculateStats(chapters: chapters, frequencyDays: project.frequencyDays)
            selectChapter(chapter)
            showingChapterNavigator = false
        } catch {
            showAlert("新建章节失败", error.localizedDescription)
        }
    }

    func adjacentChapter(offset: Int) -> Chapter? {
        guard !chapters.isEmpty else { return nil }
        guard let selectedChapter,
              let index = chapters.firstIndex(where: { $0.id == selectedChapter.id }) else {
            return offset > 0 ? chapters.first : chapters.last
        }
        let targetIndex = index + offset
        guard chapters.indices.contains(targetIndex) else { return nil }
        return chapters[targetIndex]
    }

    func selectAdjacentChapter(offset: Int) {
        guard let chapter = adjacentChapter(offset: offset) else { return }
        selectChapter(chapter)
        showingChapterNavigator = false
    }

    func requestDeleteChapter(_ chapter: Chapter) {
        let alert = NSAlert()
        alert.messageText = "删除章节？"
        alert.informativeText = "将把“第 \(chapter.meta.chapter) 章 \(chapter.meta.title)”移动到系统废纸篓，可从废纸篓找回。\n\n文件：\(chapter.fileName)\n\n如果这是当前打开的章节，本次未保存的改动不会再写入该文件。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            deleteChapter(chapter)
        }
    }

    private func deleteChapter(_ chapter: Chapter) {
        guard var project = selectedProject else { return }
        let deletingCurrent = selectedChapter?.id == chapter.id
        if !deletingCurrent {
            saveNow()
        }
        let oldIndex = chapters.firstIndex(where: { $0.id == chapter.id })
        do {
            try service.deleteChapter(project: project, chapter: chapter)
            project.updatedAt = isoNow()
            try service.updateProject(project)
            selectedProject = project
            chapters = try service.listChapters(project: project)
            stats = service.calculateStats(chapters: chapters, frequencyDays: project.frequencyDays)
            projects = try service.loadProjects()
            if deletingCurrent {
                if let oldIndex, !chapters.isEmpty {
                    let fallbackIndex = min(oldIndex, chapters.count - 1)
                    selectChapter(chapters[fallbackIndex], savingCurrent: false)
                } else {
                    clearEditor()
                }
            }
        } catch {
            showAlert("删除章节失败", error.localizedDescription)
        }
    }

    func createRelatedDoc(title: String, category: String, fileKind: RelatedDocKind = .markdown) {
        guard let project = selectedProject else { return }
        do {
            let doc = try service.createRelatedDoc(project: project, title: title, category: category, fileKind: fileKind)
            relatedDocs = try service.listRelatedDocs(project: project)
            showingNewRelatedDoc = false
            selectRelatedDoc(doc)
        } catch {
            showAlert("新建资料失败", error.localizedDescription)
        }
    }

    func importTextDoc() {
        guard let project = selectedProject else { return }
        let panel = NSOpenPanel()
        panel.title = "导入 TXT 资料"
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let doc = try self.service.importTextDoc(project: project, sourceURL: url)
                self.relatedDocs = try self.service.listRelatedDocs(project: project)
                self.selectRelatedDoc(doc)
            } catch {
                showAlert("导入 TXT 失败", error.localizedDescription)
            }
        }
    }

    func toggleDrawer(_ drawer: ReferenceDrawer) {
        referenceDrawer = referenceDrawer == drawer ? .none : drawer
    }

    func openRelatedReference(_ doc: RelatedDoc) {
        guard let project = selectedProject else { return }
        do {
            let fresh = try service.readRelatedDoc(project: project, doc: doc)
            referenceRelatedDoc = fresh.doc
            referenceRelatedBody = fresh.body
            referenceDrawer = .relatedDoc
            workspaceMode = .referencing
        } catch {
            showAlert("打开参照失败", error.localizedDescription)
        }
    }

    func openReferenceInEditor() {
        if referenceDrawer == .relatedDoc, let doc = referenceRelatedDoc {
            selectRelatedDoc(doc)
        }
        referenceDrawer = .none
    }

    func selectChapter(_ chapter: Chapter, savingCurrent: Bool = true) {
        if savingCurrent { saveNow() }
        do {
            loading = true
            let fresh = try service.readChapter(project: selectedProject!, fileName: chapter.fileName)
            selectedChapter = fresh
            selectedRelatedDoc = nil
            editorTarget = .chapter
            editorTitle = fresh.meta.title
            editorBody = fresh.body
            editorBuffer.text = fresh.body
            updateEditorStats(text: fresh.body, selectedRange: NSRange(location: 0, length: 0))
            textRequest = UUID()
            editorStatus = fresh.meta.status.isEmpty ? "drafting" : fresh.meta.status
            editorPublishAt = fresh.meta.publishAt
            editorTargetWords = fresh.meta.targetWords == 0 ? "" : String(fresh.meta.targetWords)
            editorPublished = fresh.meta.published
            lastSavedBody = fresh.body
            lastSavedMeta = fresh.meta
            snapshots = try service.listSnapshots(project: selectedProject!, key: fresh.fileName)
            saveState = "已保存"
            loading = false
        } catch {
            loading = false
            showAlert("读取章节失败", error.localizedDescription)
        }
    }

    func selectRelatedDoc(_ doc: RelatedDoc, savingCurrent: Bool = true) {
        if savingCurrent { saveNow() }
        do {
            loading = true
            let fresh = try service.readRelatedDoc(project: selectedProject!, doc: doc)
            selectedChapter = nil
            selectedRelatedDoc = fresh.doc
            editorTarget = .related
            editorTitle = fresh.doc.title
            editorBody = fresh.body
            editorBuffer.text = fresh.body
            updateEditorStats(text: fresh.body, selectedRange: NSRange(location: 0, length: 0))
            textRequest = UUID()
            editorStatus = ""
            editorPublishAt = ""
            editorTargetWords = ""
            editorPublished = false
            lastSavedBody = fresh.body
            lastSavedMeta = nil
            snapshots = try service.listSnapshots(project: selectedProject!, key: "相关/\(fresh.doc.relativePath)")
            saveState = "已保存"
            loading = false
        } catch {
            loading = false
            showAlert("读取资料失败", error.localizedDescription)
        }
    }

    func saveNow() {
        guard editorTarget != .none else { return }
        editorBody = editorBuffer.text
        do {
            try saveCurrentChapter()
            saveState = "已保存"
            markSyncedIfNeeded()
            lastSavedAt = timeNowString()
        } catch {
            saveState = "保存失败"
            showAlert("保存失败", error.localizedDescription)
        }
    }

    func revealSelectedProjectFolder() {
        guard let selectedProject else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: selectedProject.path, isDirectory: true)])
    }

    func revealSyncFolder() {
        let root = service.dataRoot
        NSWorkspace.shared.activateFileViewerSelecting([root])
    }

    func enableICloudSync() {
        do {
            let currentProjectId = selectedProject?.id
            let root = try service.enableICloudSync(settings: settings)
            settings.syncEnabled = true
            settings.syncRootPath = root.path
            settings.lastSyncAt = isoNow()
            service = FileService(settings: settings)
            try service.saveSettings(settings)
            projects = try service.loadProjects()
            if let currentProjectId, let updatedProject = projects.first(where: { $0.id == currentProjectId }) {
                openProject(updatedProject)
            }
            syncState = "已同步"
        } catch {
            syncState = "等待 iCloud"
            showAlert("开启同步失败", error.localizedDescription)
        }
    }

    func disableICloudSync() {
        do {
            saveNow()
            settings.syncEnabled = false
            settings.lastSyncAt = isoNow()
            service = FileService(settings: settings)
            try service.saveSettings(settings)
            projects = try service.loadProjects()
            syncState = "本机已保存"
        } catch {
            showAlert("关闭同步失败", error.localizedDescription)
        }
    }

    private func saveCurrentChapter() throws {
        guard var project = selectedProject else { return }
        if editorTarget == .related {
            guard let doc = selectedRelatedDoc else { return }
            guard editorBody != lastSavedBody else { return }
            try service.saveRelatedDoc(project: project, doc: doc, body: editorBody)
            lastSavedBody = editorBody
            project.updatedAt = isoNow()
            try service.updateProject(project)
            selectedProject = project
            let updatedDoc = RelatedDoc(title: doc.title, category: doc.category, url: doc.url, relativePath: doc.relativePath, wordCount: countWords(editorBody), fileKind: doc.fileKind)
            selectedRelatedDoc = updatedDoc
            if let index = relatedDocs.firstIndex(where: { $0.id == doc.id }) {
                relatedDocs[index] = updatedDoc
            }
            return
        }

        guard let chapter = selectedChapter else { return }
        var meta = chapter.meta
        meta.title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        meta.status = editorStatus
        meta.targetWords = Int(editorTargetWords) ?? 0
        meta.published = editorPublished || editorStatus == "published"
        meta.publishAt = editorPublishAt
        meta.publishedAt = meta.published ? (meta.publishedAt.isEmpty ? todayString() : meta.publishedAt) : ""
        guard editorBody != lastSavedBody || meta != lastSavedMeta else { return }
        try service.saveChapter(project: project, fileName: chapter.fileName, meta: meta, body: editorBody)
        lastSavedBody = editorBody
        lastSavedMeta = meta
        project.updatedAt = isoNow()
        try service.updateProject(project)
        selectedProject = project
        let updatedChapter = Chapter(fileName: chapter.fileName, url: chapter.url, hasFrontmatter: true, meta: meta, body: editorBody, wordCount: countWords(editorBody), missingFields: chapter.missingFields)
        selectedChapter = updatedChapter
        if let index = chapters.firstIndex(where: { $0.id == chapter.id }) {
            chapters[index] = updatedChapter
        }
        stats = service.calculateStats(chapters: chapters, frequencyDays: project.frequencyDays)
    }

    func restoreSnapshot(_ snapshot: Snapshot) {
        guard let project = selectedProject else { return }
        do {
            if editorTarget == .chapter, let chapter = selectedChapter {
                try service.restoreSnapshot(project: project, key: chapter.fileName, targetURL: chapter.url, snapshot: snapshot)
                selectChapter(chapter, savingCurrent: false)
            } else if editorTarget == .related, let doc = selectedRelatedDoc {
                try service.restoreSnapshot(project: project, key: "相关/\(doc.relativePath)", targetURL: doc.url, snapshot: snapshot)
                selectRelatedDoc(doc, savingCurrent: false)
            }
        } catch {
            showAlert("恢复快照失败", error.localizedDescription)
        }
    }

    func requestFormat() {
        formatRequest = UUID()
    }

    func saveSettings() {
        do {
            var normalized = settings
            normalized.fontSize = min(28, max(14, normalized.fontSize))
            normalized.sidebarWidth = min(320, max(170, normalized.sidebarWidth))
            normalized.detailWidth = min(380, max(220, normalized.detailWidth))
            normalized.drawerWidth = min(620, max(360, normalized.drawerWidth))
            normalized.phonePreviewFontSize = min(28, max(14, normalized.phonePreviewFontSize))
            normalized.phonePreviewHorizontalPadding = min(80, max(18, normalized.phonePreviewHorizontalPadding))
            normalized.phonePreviewLineSpacing = min(20, max(4, normalized.phonePreviewLineSpacing))
            settings = normalized
            try service.saveSettings(normalized)
            service = FileService(settings: settings)
        } catch {
            showAlert("保存外观失败", error.localizedDescription)
        }
    }

    func resetSettings() {
        settings = .defaults
        saveSettings()
    }

    func setTheme(_ themeId: String) {
        settings.themeId = themeId
        saveSettings()
    }

    func adjustFontSize(by delta: Double) {
        settings.fontSize += delta
        saveSettings()
    }

    func adjustPhonePreviewFontSize(by delta: Double) {
        settings.phonePreviewFontSize += delta
        saveSettings()
    }

    func adjustPhonePreviewHorizontalPadding(by delta: Double) {
        settings.phonePreviewHorizontalPadding += delta
        saveSettings()
    }

    func adjustPhonePreviewLineSpacing(by delta: Double) {
        settings.phonePreviewLineSpacing += delta
        saveSettings()
    }

    func toggleSidebar() {
        settings.sidebarVisible.toggle()
        if settings.sidebarVisible {
            workspaceMode = .organizing
        }
        saveSettings()
    }

    func toggleDetail() {
        settings.detailVisible.toggle()
        if settings.detailVisible {
            workspaceMode = .organizing
        }
        saveSettings()
    }

    func setSidebarWidth(_ width: Double) {
        settings.sidebarWidth = width
        saveSettings()
    }

    func setDetailWidth(_ width: Double) {
        settings.detailWidth = width
        saveSettings()
    }

    func setDrawerWidth(_ width: Double) {
        settings.drawerWidth = width
        saveSettings()
    }

    func enterFocusMode() {
        workspaceMode = .writing
        settings.sidebarVisible = false
        settings.detailVisible = false
        referenceDrawer = .none
        saveSettings()
    }

    func setWorkspaceMode(_ mode: WorkspaceMode) {
        workspaceMode = mode
        switch mode {
        case .writing:
            referenceDrawer = .none
        case .organizing:
            settings.sidebarVisible = true
            settings.detailVisible = editorTarget == .chapter
            referenceDrawer = .none
            saveSettings()
        case .referencing:
            settings.detailVisible = false
            if referenceDrawer == .none {
                if let doc = selectedRelatedDoc {
                    openRelatedReference(doc)
                } else if let doc = relatedDocs.first {
                    openRelatedReference(doc)
                }
            }
            saveSettings()
        }
    }

    func exportChapterImage() {
        editorBody = editorBuffer.text
        guard editorTarget == .chapter else {
            showAlert("无法生成图片", "请先打开一个章节。")
            return
        }
        let panel = NSSavePanel()
        panel.title = "保存章节图片"
        panel.nameFieldStringValue = safeFileName(editorTitle.isEmpty ? "未命名章节" : editorTitle) + ".png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.service.exportChapterImage(title: self.editorTitle, body: self.editorBody, settings: self.settings, to: url)
            } catch {
                showAlert("生成图片失败", error.localizedDescription)
            }
        }
    }

    private func markSyncedIfNeeded() {
        if settings.syncEnabled {
            settings.lastSyncAt = isoNow()
            syncState = "已同步"
            try? service.saveSettings(settings)
        } else {
            syncState = "本机已保存"
        }
    }

    func openPhonePreview() {
        editorBody = editorBuffer.text
        showingPhonePreview = true
    }

    func requestProofread() {
        proofreadRequest = UUID()
    }

    func runFindReplace(action: FindReplaceAction, find: String, replacement: String, options: FindReplaceOptions) {
        findReplaceRequest = FindReplaceRequest(action: action, find: find, replacement: replacement, options: options)
    }

    func findReplaceCount(find: String, options: FindReplaceOptions, inSelectionOnly: Bool = false) -> Int {
        let text = editorBuffer.text
        return rangesForFind(find, in: text, selectedRange: nil, options: options, selectionOnly: inSelectionOnly).count
    }

    func markEditorChanged() {
        guard !loading, editorTarget != .none else { return }
        if saveState != "未保存" {
            saveState = "未保存"
        }
    }

    func updateEditorStats(text: String, selectedRange: NSRange) {
        applyEditorStats(editorStats(for: text, selectedRange: selectedRange))
    }

    func applyEditorStats(_ stats: EditorStats) {
        if editorLiveWordCount != stats.totalWords {
            editorLiveWordCount = stats.totalWords
        }
        if selectedWordCount != stats.selectedWords {
            selectedWordCount = stats.selectedWords
        }
        if currentParagraphWordCount != stats.paragraphWords {
            currentParagraphWordCount = stats.paragraphWords
        }
    }

    func currentWordCount() -> Int {
        return editorLiveWordCount
    }

    func wordGapText() -> String {
        guard let target = Int(editorTargetWords), target > 0 else { return "未设目标" }
        return String(currentWordCount() - target)
    }

    func missingFields() -> String {
        var fields: [String] = []
        if editorTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fields.append("标题") }
        if editorStatus.isEmpty { fields.append("状态") }
        if editorPublishAt.isEmpty { fields.append("预计发布日期") }
        return fields.isEmpty ? "无" : fields.joined(separator: "、")
    }

    private func clearEditor() {
        selectedChapter = nil
        selectedRelatedDoc = nil
        editorTarget = .none
        editorTitle = ""
        editorBody = ""
        editorBuffer.text = ""
        updateEditorStats(text: "", selectedRange: NSRange(location: 0, length: 0))
        textRequest = UUID()
        editorStatus = "drafting"
        editorPublishAt = ""
        editorTargetWords = ""
        editorPublished = false
        lastSavedBody = ""
        lastSavedMeta = nil
        snapshots = []
        saveState = "未保存"
        lastSavedAt = ""
    }
}
