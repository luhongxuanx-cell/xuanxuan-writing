import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter = "all"
    @State private var search = ""
    @State private var sidebarMode = "目录"

    var filteredChapters: [Chapter] {
        store.chapters.filter { chapter in
            let matchesFilter = filter == "all" || chapter.meta.status == filter
            let haystack = "\(chapter.meta.chapter) \(chapter.meta.title) \(chapter.fileName)".lowercased()
            return matchesFilter && (search.isEmpty || haystack.contains(search.lowercased()))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if showsSidebar {
                SidebarPane(filter: $filter, search: $search, sidebarMode: $sidebarMode, filteredChapters: filteredChapters)
                    .frame(width: store.settings.sidebarWidth)
                ResizableDivider(width: store.settings.sidebarWidth, range: 170...320) { store.setSidebarWidth($0) }
            }

            VStack(spacing: 0) {
                DashboardBar()
                Divider()
                HStack(spacing: 0) {
                    EditorPane()
                    if showsDetail {
                        ResizableDivider(width: store.settings.detailWidth, range: 220...380) { store.setDetailWidth($0) }
                        DetailPane()
                            .frame(width: store.settings.detailWidth)
                    }
                    if showsReference {
                        ResizableDivider(width: store.settings.drawerWidth, range: 360...620) { store.setDrawerWidth($0) }
                        ReferenceDrawerView()
                            .frame(width: store.settings.drawerWidth)
                    }
                }
            }
        }
    }

    private var showsSidebar: Bool {
        store.workspaceMode == .organizing && store.settings.sidebarVisible
    }

    private var showsDetail: Bool {
        store.workspaceMode == .organizing && store.settings.detailVisible
    }

    private var showsReference: Bool {
        store.workspaceMode == .referencing && store.referenceDrawer != .none
    }
}

struct SidebarPane: View {
    @EnvironmentObject var store: AppStore
    @Binding var filter: String
    @Binding var search: String
    @Binding var sidebarMode: String
    let filteredChapters: [Chapter]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextSegmentedControl(selection: $sidebarMode, items: ["目录", "相关"])
                if sidebarMode == "目录" {
                    Menu(statusFilterTitle) {
                        Button("全部") { filter = "all" }
                        Button("写作") { filter = "drafting" }
                        Button("存稿") { filter = "ready" }
                        Button("已发") { filter = "published" }
                    }
                    .menuStyle(.borderlessButton)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(store.settings.secondaryTextColor)
                }
            }

            if sidebarMode == "目录" {
                TextField("搜索章节", text: $search)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundColor(store.settings.primaryTextColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(store.settings.inputBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredChapters) { chapter in
                            ChapterRow(chapter: chapter)
                                .contentShape(Rectangle())
                                .onTapGesture { store.selectChapter(chapter) }
                            Divider().background(store.settings.borderColor.opacity(0.45))
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                HStack(spacing: 8) {
                    Button("+ 新建资料") { store.showingNewRelatedDoc = true }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("导入 TXT") { store.importTextDoc() }
                        .buttonStyle(QuietButtonStyle())
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(relatedCategories, id: \.self) { category in
                            let docs = store.relatedDocs.filter { $0.category == category }
                            if !docs.isEmpty {
                                ThemedSectionTitle(category)
                                ForEach(docs) { doc in
                                    RelatedDocRow(doc: doc) {
                                        store.selectRelatedDoc(doc)
                                    } referenceAction: {
                                        store.openRelatedReference(doc)
                                    }
                                    Divider().background(store.settings.borderColor.opacity(0.45))
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(12)
        .background(store.settings.sidebarBackgroundColor)
    }

    private var statusFilterTitle: String {
        switch filter {
        case "drafting": return "写作"
        case "ready": return "存稿"
        case "published": return "已发"
        default: return "全部"
        }
    }
}

struct TextSegmentedControl: View {
    @EnvironmentObject var store: AppStore
    @Binding var selection: String
    let items: [String]
    var labels: [String: String] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button(labels[item] ?? item) {
                    selection = item
                }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundColor(selection == item ? store.settings.primaryTextColor : store.settings.secondaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(selection == item ? store.settings.inputBackgroundColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(2)
        .background(store.settings.cardBackgroundColor.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(store.settings.borderColor.opacity(0.45)))
    }
}

struct ThemedSectionTitle: View {
    @EnvironmentObject var store: AppStore
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(store.settings.secondaryTextColor)
            .padding(.top, 6)
    }
}

struct RelatedToolRow: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let note: String
    let openAction: () -> Void
    let referenceAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(store.settings.primaryTextColor)
                Text(note)
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: openAction)
            Spacer()
            Button("参照", action: referenceAction)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct ResizableDivider: View {
    @EnvironmentObject var store: AppStore
    let width: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void
    @State private var dragStartWidth: Double?

    var body: some View {
        Rectangle()
            .fill(store.settings.borderColor.opacity(0.8))
            .frame(width: 6)
            .overlay(Rectangle().fill(Color.clear).frame(width: 14))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let base = dragStartWidth ?? width
                        if dragStartWidth == nil { dragStartWidth = width }
                        onChange(min(range.upperBound, max(range.lowerBound, base + value.translation.width)))
                    }
                    .onEnded { _ in
                        dragStartWidth = nil
                    }
            )
    }
}

struct DashboardBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 12) {
            Button("书架") { store.backToShelf() }
                .buttonStyle(QuietButtonStyle())

            ChapterToolbarControl()

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(store.selectedProject?.name ?? appDisplayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(store.settings.primaryTextColor)
                        .lineLimit(1)
                    if let project = store.selectedProject {
                        Button("改名") { store.beginEditProject(project) }
                            .font(.caption)
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(store.settings.secondaryTextColor)
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
                    .lineLimit(1)
            }
            .frame(minWidth: 220, alignment: .leading)

            Spacer(minLength: 16)
            SaveStatePill()
            Button("保存") { store.saveNow() }
                .buttonStyle(PrimaryButtonStyle())
            Button("预览") { store.openPhonePreview() }
                .buttonStyle(QuietButtonStyle())
            Button("命令") { store.showingCommandPalette = true }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut("k", modifiers: [.command])
            MoreToolsMenu()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(store.settings.appBackgroundColor)
    }

    private var subtitle: String {
        if let chapter = store.selectedChapter {
            return "第 \(chapter.meta.chapter) 章 · \(chapter.meta.title)"
        }
        if let doc = store.selectedRelatedDoc {
            return "相关 · \(doc.category) · \(doc.title)"
        }
        return store.stats.nextChapterTitle.isEmpty ? "暂无下一章" : "下一章：\(store.stats.nextChapterTitle)"
    }

}

struct ChapterToolbarControl: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 6) {
            Button {
                store.showingChapterNavigator.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("章节")
                        .font(.callout.weight(.semibold))
                    Text(currentChapterText)
                        .font(.caption)
                        .lineLimit(1)
                    Text("▾")
                        .font(.caption.weight(.bold))
                }
                .frame(maxWidth: 260, alignment: .leading)
            }
            .buttonStyle(QuietButtonStyle())
            .keyboardShortcut("j", modifiers: [.command])
            .popover(isPresented: $store.showingChapterNavigator, arrowEdge: .bottom) {
                ChapterNavigatorPanel()
                    .environmentObject(store)
                    .frame(width: 430, height: 560)
            }

            Button("新章") { store.showingNewChapter = true }
                .buttonStyle(PrimaryButtonStyle())

            Button("删除") {
                if let chapter = store.selectedChapter {
                    store.requestDeleteChapter(chapter)
                }
            }
            .buttonStyle(DangerButtonStyle())
            .disabled(store.selectedChapter == nil)
        }
    }

    private var currentChapterText: String {
        guard let chapter = store.selectedChapter else {
            return "未打开章节"
        }
        let title = chapter.meta.title.isEmpty ? "未命名章节" : chapter.meta.title
        return "第 \(chapter.meta.chapter) 章 · \(title)"
    }
}

struct ChapterNavigatorPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var filter = "all"

    private var filteredChapters: [Chapter] {
        store.chapters.filter { chapter in
            let matchesFilter = filter == "all" || chapter.meta.status == filter
            let haystack = "\(chapter.meta.chapter) \(chapter.meta.title) \(chapter.fileName)".lowercased()
            return matchesFilter && (search.isEmpty || haystack.contains(search.lowercased()))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("章节目录")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(store.settings.primaryTextColor)
                    Text(store.selectedChapter.map { "当前：第 \($0.meta.chapter) 章 \($0.meta.title)" } ?? "当前未打开章节")
                        .font(.caption)
                        .foregroundColor(store.settings.secondaryTextColor)
                        .lineLimit(1)
                }
                Spacer()
                Button("+ 新章") {
                    store.showingNewChapter = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            HStack(spacing: 8) {
                Button("上一章") { store.selectAdjacentChapter(offset: -1) }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(store.adjacentChapter(offset: -1) == nil)
                Button("下一章") { store.selectAdjacentChapter(offset: 1) }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(store.adjacentChapter(offset: 1) == nil)
                Spacer()
                Menu(statusFilterTitle) {
                    Button("全部") { filter = "all" }
                    Button("写作") { filter = "drafting" }
                    Button("存稿") { filter = "ready" }
                    Button("已发") { filter = "published" }
                }
                .menuStyle(.borderlessButton)
                .font(.caption.weight(.semibold))
                .foregroundColor(store.settings.secondaryTextColor)
            }

            TextField("搜索章节", text: $search)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundColor(store.settings.primaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(store.settings.inputBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()
                .background(store.settings.borderColor.opacity(0.5))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredChapters) { chapter in
                        HStack(spacing: 6) {
                            Button {
                                store.selectChapter(chapter)
                                store.showingChapterNavigator = false
                            } label: {
                                ChapterRow(chapter: chapter)
                            }
                            .buttonStyle(.plain)

                            Button("删除") {
                                store.requestDeleteChapter(chapter)
                            }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .background(store.settings.cardBackgroundColor.opacity(0.72))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(store.settings.borderColor.opacity(0.55)))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        Divider().background(store.settings.borderColor.opacity(0.45))
                    }
                }
                .padding(.vertical, 4)
            }

            if filteredChapters.isEmpty {
                Text("没有匹配的章节。")
                    .font(.caption)
                    .foregroundColor(store.settings.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(14)
        .background(store.settings.panelBackgroundColor)
    }

    private var statusFilterTitle: String {
        switch filter {
        case "drafting": return "写作"
        case "ready": return "存稿"
        case "published": return "已发"
        default: return "全部"
        }
    }
}

struct WorkspaceModeControl: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceMode.allCases) { mode in
                Button(mode.title) {
                    store.setWorkspaceMode(mode)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundColor(store.workspaceMode == mode ? .white : store.settings.secondaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(store.workspaceMode == mode ? store.settings.accentColor : Color.clear)
                .clipShape(Capsule())
            }
        }
        .padding(3)
        .background(store.settings.cardBackgroundColor.opacity(0.56))
        .overlay(Capsule().stroke(store.settings.borderColor.opacity(0.65)))
        .clipShape(Capsule())
    }
}

struct MoreToolsMenu: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Menu("更多") {
            Menu("模式") {
                Button("写作模式") { store.setWorkspaceMode(.writing) }
                Button("整理模式") { store.setWorkspaceMode(.organizing) }
                Button("参照模式") { store.setWorkspaceMode(.referencing) }
            }
            Button("打开命令盘") { store.showingCommandPalette = true }
                .keyboardShortcut("k", modifiers: [.command])
            Divider()
            Button("分段") { store.requestFormat() }
            Button("查找替换") { store.showingFindReplace = true }
                .keyboardShortcut("f", modifiers: [.command])
            Button("校对") { store.requestProofread() }
            Button("导出图片") { store.exportChapterImage() }
            Button("导入 TXT") { store.importTextDoc() }
            Divider()
            Menu("主题") {
                ForEach(writingThemes) { theme in
                    Button(theme.name) { store.setTheme(theme.id) }
                }
            }
            Menu("字号") {
                Button("A-") { store.adjustFontSize(by: -1) }
                    .disabled(store.settings.fontSize <= 14)
                Button("A+") { store.adjustFontSize(by: 1) }
                    .disabled(store.settings.fontSize >= 28)
                Text("当前 \(Int(store.settings.fontSize))")
            }
            Divider()
            Button(store.settings.syncEnabled ? "同步设置" : "开启同步") { store.showingSyncSettings = true }
            Button("专注写作") { store.enterFocusMode() }
        }
        .menuStyle(.borderlessButton)
        .foregroundColor(store.settings.primaryTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(store.settings.cardBackgroundColor)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.settings.borderColor.opacity(0.7)))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SaveStatePill: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Text(store.saveState)
            .font(.caption.weight(.semibold))
            .foregroundColor(store.saveState == "保存失败" ? .red : store.settings.secondaryTextColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(store.settings.cardBackgroundColor.opacity(0.78))
            .overlay(Capsule().stroke(store.settings.borderColor))
            .clipShape(Capsule())
    }
}

struct LayoutToggleButton: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? store.settings.accentColor : store.settings.cardBackgroundColor)
            .foregroundColor(isOn ? .white : store.settings.editorTextColor)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(store.settings.borderColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EditorPane: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ZStack {
            store.settings.appBackgroundColor.opacity(0.72)
            HStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(editorEyebrow)
                                .font(.caption)
                                .foregroundColor(store.settings.secondaryTextColor)
                            TextField("章节标题", text: $store.editorTitle)
                                .font(.title2.weight(.bold))
                                .textFieldStyle(.plain)
                                .foregroundColor(store.settings.editorTextColor)
                                .disabled(store.editorTarget != .chapter)
                                .onChange(of: store.editorTitle) { _, _ in store.markEditorChanged() }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                    Divider()
                        .background(store.settings.borderColor.opacity(0.45))
                    SelectableTextEditor(
                        text: $store.editorBody,
                        formatRequest: store.formatRequest,
                        textRequest: store.textRequest,
                        proofreadRequest: store.proofreadRequest,
                        findReplaceRequest: store.findReplaceRequest,
                        settings: store.settings,
                        buffer: store.editorBuffer,
                        onTextChange: { store.markEditorChanged() },
                        onStatsChange: { stats in
                            store.applyEditorStats(stats)
                        }
                    )
                    .disabled(store.editorTarget == .none)
                    Divider()
                        .background(store.settings.borderColor.opacity(0.45))
                    WritingStatusBar()
                }
                .frame(maxWidth: 920)
                .background(store.settings.editorBackgroundColor)
                .overlay(Rectangle().stroke(store.settings.borderColor.opacity(0.48), lineWidth: 1))
                Spacer(minLength: 24)
            }
        }
    }

    private var editorEyebrow: String {
        if let chapter = store.selectedChapter {
            return "第 \(chapter.meta.chapter) 章"
        }
        if let doc = store.selectedRelatedDoc {
            return "相关 / \(doc.category)"
        }
        return "编辑"
    }
}

struct WritingStatusBar: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 10) {
            Text(documentLabel)
            Text("\(store.editorLiveWordCount) 字")
            Text("·")
                .foregroundColor(store.settings.mutedTextColor)
            Text("当前段落 \(store.currentParagraphWordCount) 字")
            if store.selectedWordCount > 0 {
                Text("·")
                    .foregroundColor(store.settings.mutedTextColor)
                Text("已选 \(store.selectedWordCount) 字")
                    .foregroundColor(store.settings.primaryTextColor)
            }
            Spacer()
            Text(store.saveState)
        }
        .font(.caption)
        .foregroundColor(store.settings.secondaryTextColor)
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(store.settings.editorBackgroundColor)
    }

    private var documentLabel: String {
        switch store.editorTarget {
        case .chapter: return "本章"
        case .related: return "资料"
        case .none: return "未打开"
        }
    }
}

struct DetailPane: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.editorTarget == .chapter {
                    GroupBox("章节管理") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("状态", selection: $store.editorStatus) {
                                ForEach(statuses, id: \.self) { status in
                                    Text(statusLabels[status] ?? status).tag(status)
                                }
                            }
                            .onChange(of: store.editorStatus) { _, _ in store.markEditorChanged() }
                            TextField("预计发布日期", text: $store.editorPublishAt)
                                .onChange(of: store.editorPublishAt) { _, _ in store.markEditorChanged() }
                            TextField("目标字数", text: $store.editorTargetWords)
                                .onChange(of: store.editorTargetWords) { _, _ in store.markEditorChanged() }
                            Toggle("已发布", isOn: $store.editorPublished)
                                .onChange(of: store.editorPublished) { _, _ in store.markEditorChanged() }
                        }
                        .padding(.top, 4)
                    }
                } else if let doc = store.selectedRelatedDoc {
                    GroupBox("相关资料") {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow("类别", doc.category)
                            InfoRow("文件", doc.relativePath)
                        }
                    }
                }

                GroupBox(store.editorTarget == .chapter ? "本章数据" : "资料数据") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow("当前字数", "\(store.currentWordCount())")
                        if store.editorTarget == .chapter {
                            InfoRow("目标差额", store.wordGapText())
                            InfoRow("文件", store.selectedChapter?.fileName ?? "-")
                        } else {
                            InfoRow("文件", store.selectedRelatedDoc?.relativePath ?? "-")
                        }
                    }
                }

                GroupBox("本机保存") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow("保存状态", store.saveState)
                        InfoRow("最近保存", store.lastSavedAt.isEmpty ? "本次尚未手动保存" : store.lastSavedAt)
                        InfoRow("快照", store.snapshots.isEmpty ? "暂无快照" : "latest.md")
                        Button("显示作品文件夹") {
                            store.revealSelectedProjectFolder()
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }

                if store.editorTarget == .chapter {
                    GroupBox("待补信息") {
                    Text(store.missingFields())
                            .foregroundColor(store.settings.secondaryTextColor)
                    }
                }

                GroupBox("快照") {
                    if store.snapshots.isEmpty {
                        Text("暂无快照")
                            .foregroundColor(store.settings.secondaryTextColor)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(store.snapshots.prefix(8)) { snapshot in
                                Button(snapshot.createdAt.formatted(date: .numeric, time: .standard)) {
                                    store.restoreSnapshot(snapshot)
                                }
                                .buttonStyle(QuietButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(store.settings.panelBackgroundColor)
    }
}

struct ThemeSwitcher: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TextSegmentedControl(selection: themeBinding, items: writingThemes.map(\.id), labels: Dictionary(uniqueKeysWithValues: writingThemes.map { ($0.id, $0.name) }))
        .frame(width: 260)
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { store.settings.themeId },
            set: { store.setTheme($0) }
        )
    }
}

struct FontSizeControl: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 6) {
            Button("A-") { store.adjustFontSize(by: -1) }
                .buttonStyle(QuietButtonStyle())
                .disabled(store.settings.fontSize <= 14)
            Text("\(Int(store.settings.fontSize))")
                .font(.caption.weight(.semibold))
                .foregroundColor(store.settings.primaryTextColor)
                .frame(width: 26)
            Button("A+") { store.adjustFontSize(by: 1) }
                .buttonStyle(QuietButtonStyle())
                .disabled(store.settings.fontSize >= 28)
        }
    }
}

struct ReferenceDrawerView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(drawerTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(store.settings.primaryTextColor)
                Spacer()
                Button("主编辑") { store.openReferenceInEditor() }
                    .buttonStyle(QuietButtonStyle())
                Button("关闭") { store.referenceDrawer = .none }
                    .buttonStyle(QuietButtonStyle())
            }
            .padding(14)
            Divider()
            if store.referenceDrawer == .relatedDoc {
                RelatedReferenceView()
            }
        }
        .background(store.settings.panelBackgroundColor)
    }

    private var drawerTitle: String {
        switch store.referenceDrawer {
        case .relatedDoc: return store.referenceRelatedDoc?.title ?? "相关资料"
        case .none: return ""
        }
    }
}

struct RelatedReferenceView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let doc = store.referenceRelatedDoc {
                    HStack(spacing: 8) {
                        RelatedKindBadge(kind: doc.fileKind)
                        Text(doc.category)
                            .font(.caption)
                            .foregroundColor(store.settings.secondaryTextColor)
                    }
                    Text(doc.title)
                        .font(.title3.weight(.semibold))
                        .foregroundColor(store.settings.primaryTextColor)
                    Divider()
                    Text(store.referenceRelatedBody.isEmpty ? "暂无内容" : store.referenceRelatedBody)
                        .font(.body)
                        .foregroundColor(store.settings.primaryTextColor)
                        .lineSpacing(6)
                        .textSelection(.enabled)
                } else {
                    Text("暂无参照资料")
                        .foregroundColor(store.settings.secondaryTextColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
