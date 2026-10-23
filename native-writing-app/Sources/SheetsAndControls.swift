import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct NewProjectView: View {
    @EnvironmentObject var store: AppStore
    @State private var name = ""
    @State private var description = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建作品").font(.title2.weight(.bold))
            TextField("作品名", text: $name)
            TextField("简介（可选）", text: $description, axis: .vertical)
                .lineLimit(3...5)
            HStack {
                Spacer()
                Button("取消") { store.showingNewProject = false }
                Button("创建并进入") {
                    store.showingNewProject = false
                    store.createProject(name: name, description: description)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }
}

struct SyncSettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("iCloud 同步")
                    .font(.title2.weight(.bold))
                    .foregroundColor(store.settings.primaryTextColor)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(store.settings.syncEnabled ? "已连接共享文件夹" : "当前只保存在这台 Mac")
                    .font(.headline)
                    .foregroundColor(store.settings.primaryTextColor)
                Text(store.settings.syncEnabled ? "当前使用手动选择的作品文件夹。跨设备时，两端应选择同一个 iCloud Drive 文件夹。" : "选择含 projects.json 和 projects 的文件夹。不会自动复制或合并本机作品。")
                    .foregroundColor(store.settings.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                if store.settings.syncEnabled {
                    Text(store.settings.syncRootPath)
                        .font(.caption)
                        .foregroundColor(store.settings.mutedTextColor)
                        .lineLimit(3)
                    Text(store.settings.lastSyncAt.isEmpty ? "最近同步：暂无" : "最近同步：\(store.settings.lastSyncAt)")
                        .font(.caption)
                        .foregroundColor(store.settings.secondaryTextColor)
                }
            }
            .padding(14)
            .background(store.settings.cardBackgroundColor)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(store.settings.borderColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                if store.settings.syncEnabled {
                    Button("显示同步文件夹") { store.revealSyncFolder() }
                        .buttonStyle(QuietButtonStyle())
                    Button("返回本机演示库") { store.disableICloudSync() }
                        .buttonStyle(QuietButtonStyle())
                } else {
                    Button("选择共享文件夹") { store.enableICloudSync() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Spacer()
            }

            Text("手机端第一版会读取同一套 iCloud 文件：书架、章节和相关资料会同步。")
                .font(.caption)
                .foregroundColor(store.settings.mutedTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(store.settings.panelBackgroundColor)
    }
}

struct FindReplacePanel: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var findText = ""
    @State private var replacement = ""
    @State private var caseSensitive = false
    @State private var wholeWord = false
    @State private var message = ""

    private var options: FindReplaceOptions {
        FindReplaceOptions(caseSensitive: caseSensitive, wholeWord: wholeWord)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("查找替换")
                    .font(.title2.weight(.bold))
                    .foregroundColor(store.settings.primaryTextColor)
                Spacer()
                Button("完成") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                TextField("查找内容", text: $findText)
                    .textFieldStyle(.roundedBorder)
                TextField("替换为", text: $replacement)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Toggle("区分大小写", isOn: $caseSensitive)
                    Toggle("完整词匹配", isOn: $wholeWord)
                }
                .font(.caption)
                .foregroundColor(store.settings.secondaryTextColor)
            }

            HStack(spacing: 8) {
                Button("上一个") { run(.findPrevious) }
                    .buttonStyle(QuietButtonStyle())
                Button("下一个") { run(.findNext) }
                    .buttonStyle(QuietButtonStyle())
                Button("替换当前") { run(.replaceCurrent) }
                    .buttonStyle(QuietButtonStyle())
                Button("替换选区") { run(.replaceSelection) }
                    .buttonStyle(QuietButtonStyle())
                Button("全部替换") { confirmReplaceAll() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .disabled(findText.isEmpty)

            Text(message.isEmpty ? "只作用于当前打开的章节或资料；全部替换前会确认数量。" : message)
                .font(.caption)
                .foregroundColor(store.settings.mutedTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(store.settings.panelBackgroundColor)
    }

    private func run(_ action: FindReplaceAction) {
        store.runFindReplace(action: action, find: findText, replacement: replacement, options: options)
        if action == .replaceSelection {
            message = "已尝试替换当前选区。"
        }
    }

    private func confirmReplaceAll() {
        let count = store.findReplaceCount(find: findText, options: options)
        guard count > 0 else {
            message = "没有找到匹配内容。"
            return
        }
        let alert = NSAlert()
        alert.messageText = "确认全部替换？"
        alert.informativeText = "将在当前文本中替换 \(count) 处。这个操作可以用 Command+Z 撤回。"
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            run(.replaceAll)
            message = "已替换 \(count) 处。"
        }
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var matchingChapters: [Chapter] {
        guard !normalizedQuery.isEmpty else { return Array(store.chapters.prefix(6)) }
        return store.chapters.filter { chapter in
            "\(chapter.meta.chapter) \(chapter.meta.title) \(chapter.fileName)".lowercased().contains(normalizedQuery)
        }
    }

    private var matchingDocs: [RelatedDoc] {
        guard !normalizedQuery.isEmpty else { return Array(store.relatedDocs.prefix(8)) }
        return store.relatedDocs.filter { doc in
            "\(doc.title) \(doc.category) \(doc.relativePath) \(doc.fileKind.badge)".lowercased().contains(normalizedQuery)
        }
    }

    private var matchingTools: [PaletteTool] {
        let tools = PaletteTool.defaults
        guard !normalizedQuery.isEmpty else { return tools }
        return tools.filter { "\($0.title) \($0.note)".lowercased().contains(normalizedQuery) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("命令")
                    .font(.title2.weight(.bold))
                    .foregroundColor(store.settings.primaryTextColor)
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
            }

            TextField("搜索章节、资料、TXT 或工具", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .foregroundColor(store.settings.primaryTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(store.settings.inputBackgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.settings.borderColor.opacity(0.75)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !matchingChapters.isEmpty {
                        CommandSectionTitle("章节")
                        ForEach(matchingChapters.prefix(12)) { chapter in
                            CommandRow(
                                icon: "第 \(chapter.meta.chapter == 0 ? "?" : String(chapter.meta.chapter))",
                                title: chapter.meta.title.isEmpty ? "未命名章节" : chapter.meta.title,
                                note: "\(chapter.wordCount) 字 · \(statusLabels[chapter.meta.status] ?? "待补")",
                                actionTitle: "打开"
                            ) {
                                store.selectChapter(chapter)
                                dismiss()
                            }
                        }
                    }

                    if !matchingDocs.isEmpty {
                        CommandSectionTitle("资料")
                        ForEach(matchingDocs.prefix(14)) { doc in
                            CommandRow(
                                icon: doc.fileKind.badge,
                                title: doc.title,
                                note: "\(doc.category) · \(doc.relativePath)",
                                actionTitle: "参照",
                                secondaryTitle: "编辑",
                                secondaryAction: {
                                    store.selectRelatedDoc(doc)
                                    dismiss()
                                }
                            ) {
                                store.openRelatedReference(doc)
                                dismiss()
                            }
                        }
                    }

                    if !matchingTools.isEmpty {
                        CommandSectionTitle("工具")
                        ForEach(matchingTools) { tool in
                            CommandRow(icon: tool.icon, title: tool.title, note: tool.note, actionTitle: "执行") {
                                run(tool)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(22)
        .background(store.settings.panelBackgroundColor)
    }

    private func run(_ tool: PaletteTool) {
        switch tool.kind {
        case .writingMode:
            store.setWorkspaceMode(.writing)
        case .organizingMode:
            store.setWorkspaceMode(.organizing)
        case .referencingMode:
            store.setWorkspaceMode(.referencing)
        case .newChapter:
            store.showingNewChapter = true
        case .newRelatedDoc:
            store.showingNewRelatedDoc = true
        case .importText:
            store.importTextDoc()
        case .format:
            store.requestFormat()
        case .findReplace:
            store.showingFindReplace = true
        case .proofread:
            store.requestProofread()
        case .phonePreview:
            store.openPhonePreview()
        case .exportImage:
            store.exportChapterImage()
        case .sync:
            store.showingSyncSettings = true
        }
    }
}

struct PaletteTool: Identifiable {
    enum Kind {
        case writingMode, organizingMode, referencingMode, newChapter, newRelatedDoc, importText
        case format, findReplace, proofread, phonePreview, exportImage, sync
    }

    var id: Kind { kind }
    var kind: Kind
    var icon: String
    var title: String
    var note: String

    static let defaults: [PaletteTool] = [
        PaletteTool(kind: .writingMode, icon: "写", title: "写作模式", note: "只保留正文纸面"),
        PaletteTool(kind: .organizingMode, icon: "整", title: "整理模式", note: "打开目录和管理栏"),
        PaletteTool(kind: .referencingMode, icon: "参", title: "参照模式", note: "右侧呼出资料"),
        PaletteTool(kind: .newChapter, icon: "+", title: "新建章节", note: "创建下一章"),
        PaletteTool(kind: .newRelatedDoc, icon: "+", title: "新建资料", note: "创建 MD 或 TXT 资料"),
        PaletteTool(kind: .importText, icon: "TXT", title: "导入 TXT", note: "复制 txt 到当前作品"),
        PaletteTool(kind: .format, icon: "段", title: "自动分段", note: "整理当前选区或全文段落"),
        PaletteTool(kind: .findReplace, icon: "找", title: "查找替换", note: "只处理当前文档"),
        PaletteTool(kind: .proofread, icon: "校", title: "中文校对", note: "打开系统拼写检查"),
        PaletteTool(kind: .phonePreview, icon: "预", title: "手机预览", note: "查看手机阅读效果"),
        PaletteTool(kind: .exportImage, icon: "图", title: "导出章节图片", note: "生成当前章节图片"),
        PaletteTool(kind: .sync, icon: "云", title: "同步设置", note: "查看或开启 iCloud Drive")
    ]
}

struct CommandSectionTitle: View {
    @EnvironmentObject var store: AppStore
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundColor(store.settings.secondaryTextColor)
            .padding(.top, 4)
    }
}

struct CommandRow: View {
    @EnvironmentObject var store: AppStore
    let icon: String
    let title: String
    let note: String
    let actionTitle: String
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.caption.weight(.bold))
                .foregroundColor(store.settings.accentColor)
                .frame(width: 34, height: 28)
                .background(store.settings.cardBackgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.settings.borderColor.opacity(0.65)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(store.settings.primaryTextColor)
                    .lineLimit(1)
                Text(note)
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
                    .lineLimit(1)
            }
            Spacer()
            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .buttonStyle(QuietButtonStyle())
            }
            Button(actionTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(10)
        .background(store.settings.cardBackgroundColor.opacity(0.56))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(store.settings.borderColor.opacity(0.45)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct EditProjectView: View {
    @EnvironmentObject var store: AppStore
    let project: WritingProject
    @State private var name: String
    @State private var description: String

    init(project: WritingProject) {
        self.project = project
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("编辑书名").font(.title2.weight(.bold))
            TextField("书名", text: $name)
            TextField("简介（可选）", text: $description, axis: .vertical)
                .lineLimit(3...5)
            Text("只改显示名称，不移动作品文件夹。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") {
                    store.showingEditProject = false
                    store.editingProject = nil
                }
                Button("保存") {
                    store.updateProjectDetails(name: name, description: description)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }
}

struct NewChapterView: View {
    @EnvironmentObject var store: AppStore
    @State private var title = "新章节"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建章节").font(.title2.weight(.bold))
            TextField("章节标题", text: $title)
            HStack {
                Spacer()
                Button("取消") { store.showingNewChapter = false }
                Button("创建") {
                    store.showingNewChapter = false
                    store.createChapter(title: title)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(22)
    }
}

struct NewRelatedDocView: View {
    @EnvironmentObject var store: AppStore
    @State private var title = "新资料"
    @State private var category = relatedCategories[0]
    @State private var fileKind: RelatedDocKind = .markdown

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建资料").font(.title2.weight(.bold))
            TextField("资料标题", text: $title)
            Picker("分类", selection: $category) {
                ForEach(relatedCategories, id: \.self) { item in
                    Text(item).tag(item)
                }
            }
            .pickerStyle(.segmented)
            Picker("格式", selection: $fileKind) {
                ForEach(RelatedDocKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Text(fileKind == .markdown ? "Markdown 适合写设定和大纲；TXT 会保持纯文本格式。" : "TXT 会创建为纯文本文件，之后像正文一样编辑。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("取消") { store.showingNewRelatedDoc = false }
                Button("创建并打开") {
                    store.createRelatedDoc(title: title, category: category, fileKind: fileKind)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
    }
}

struct PhonePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppStore
    let title: String
    let bodyText: String

    var paragraphs: [String] {
        bodyText.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.isEmpty ? "未命名章节" : title)
                    .font(.headline)
                    .foregroundColor(store.settings.editorTextColor)
                    .lineLimit(1)
                Spacer()
                Button("返回编辑") {
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            Divider()
            HStack(spacing: 8) {
                PreviewAdjustButton("A-") { store.adjustPhonePreviewFontSize(by: -1) }
                Text("\(Int(store.settings.phonePreviewFontSize))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(store.settings.secondaryTextColor)
                    .frame(width: 28)
                PreviewAdjustButton("A+") { store.adjustPhonePreviewFontSize(by: 1) }
                Divider().frame(height: 18)
                PreviewAdjustButton("窄") { store.adjustPhonePreviewHorizontalPadding(by: -4) }
                Text("边距")
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
                PreviewAdjustButton("宽") { store.adjustPhonePreviewHorizontalPadding(by: 4) }
                Divider().frame(height: 18)
                PreviewAdjustButton("紧") { store.adjustPhonePreviewLineSpacing(by: -1) }
                Text("行距")
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
                PreviewAdjustButton("松") { store.adjustPhonePreviewLineSpacing(by: 1) }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(store.settings.panelBackgroundColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text("　　\(paragraph)")
                            .font(Font.custom(store.settings.fontName, size: store.settings.phonePreviewFontSize))
                            .foregroundColor(store.settings.editorTextColor)
                            .lineSpacing(store.settings.phonePreviewLineSpacing)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, store.settings.phonePreviewHorizontalPadding)
                .padding(.top, 46)
                .padding(.bottom, 90)
            }
        }
        .background(store.settings.editorBackgroundColor)
    }
}

struct PreviewAdjustButton: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundColor(store.settings.primaryTextColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(store.settings.cardBackgroundColor)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.settings.borderColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct ChapterRow: View {
    @EnvironmentObject var store: AppStore
    let chapter: Chapter

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(chapter.meta.chapter == 0 ? "?" : String(chapter.meta.chapter))
                .font(.caption.weight(.semibold))
                .foregroundColor(store.settings.mutedTextColor)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.meta.title.isEmpty ? "未命名章节" : chapter.meta.title)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(store.settings.primaryTextColor)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text("\(chapter.wordCount) 字")
                    Text(statusLabels[chapter.meta.status] ?? "待补")
                }
                .font(.caption)
                .foregroundColor(store.settings.secondaryTextColor)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? store.settings.selectedBackgroundColor.opacity(0.62) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var isSelected: Bool {
        store.selectedChapter?.id == chapter.id
    }
}

struct RelatedDocRow: View {
    @EnvironmentObject var store: AppStore
    let doc: RelatedDoc
    let openAction: () -> Void
    let referenceAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    RelatedKindBadge(kind: doc.fileKind)
                    Text(doc.title)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(store.settings.primaryTextColor)
                        .lineLimit(1)
                }
                HStack {
                    Text("\(doc.wordCount) 字")
                    Text(doc.relativePath)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(store.settings.secondaryTextColor)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: openAction)
            Spacer()
            Button("参照", action: referenceAction)
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundColor(store.settings.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isSelected ? store.settings.selectedBackgroundColor.opacity(0.62) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var isSelected: Bool {
        store.selectedRelatedDoc?.id == doc.id
    }
}

struct RelatedKindBadge: View {
    @EnvironmentObject var store: AppStore
    let kind: RelatedDocKind

    var body: some View {
        Text(kind.badge)
            .font(.caption2.weight(.bold))
            .foregroundColor(kind == .text ? store.settings.accentColor : store.settings.secondaryTextColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(store.settings.cardBackgroundColor.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(store.settings.borderColor.opacity(0.65)))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct MetricBox: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let value: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundColor(store.settings.secondaryTextColor)
            Text(value).font(.title3.weight(.bold)).foregroundColor(store.settings.primaryTextColor)
            Text(note).font(.caption2).foregroundColor(store.settings.secondaryTextColor)
        }
        .padding(12)
        .frame(minWidth: 104, alignment: .leading)
        .background(store.settings.cardBackgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.settings.borderColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CapsuleLabel: View {
    @EnvironmentObject var store: AppStore
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(store.settings.secondaryTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(store.settings.borderColor))
    }
}

struct InfoRow: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let value: String
    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
    var body: some View {
        HStack {
            Text(title).foregroundColor(store.settings.secondaryTextColor)
            Spacer()
            Text(value).foregroundColor(store.settings.primaryTextColor).lineLimit(2)
        }
        .font(.caption)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject var store: AppStore

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(configuration.isPressed ? store.settings.accentColor.opacity(0.8) : store.settings.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct QuietButtonStyle: ButtonStyle {
    @EnvironmentObject var store: AppStore

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(store.settings.primaryTextColor)
            .background(configuration.isPressed ? store.settings.selectedBackgroundColor.opacity(0.65) : store.settings.cardBackgroundColor.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.settings.borderColor.opacity(0.62)))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct DangerButtonStyle: ButtonStyle {
    @EnvironmentObject var store: AppStore
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isEnabled ? .red : store.settings.mutedTextColor)
            .background(configuration.isPressed ? Color.red.opacity(0.14) : store.settings.cardBackgroundColor.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(isEnabled ? Color.red.opacity(0.35) : store.settings.borderColor.opacity(0.62)))
            .clipShape(RoundedRectangle(cornerRadius: 9))
    }
}

extension Color {
    static let appBackground = Color(red: 0.965, green: 0.953, blue: 0.925)
    static let sidebarBackground = Color(red: 0.925, green: 0.908, blue: 0.86)
    static let cardBackground = Color(red: 1.0, green: 0.992, blue: 0.972)
    static let editorBackground = Color.white
    static let panelBackground = Color(red: 0.945, green: 0.933, blue: 0.90)
    static let border = Color(red: 0.86, green: 0.84, blue: 0.79)
    static let accentSoft = Color(red: 0.184, green: 0.435, blue: 0.45)
}
