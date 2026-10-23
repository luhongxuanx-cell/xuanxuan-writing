import SwiftUI
import UIKit
import UniformTypeIdentifiers

@main
struct XuanxuanWritingMobileApp: App {
    var body: some Scene {
        WindowGroup {
            MobileBookshelfView()
        }
    }
}

struct MobileTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let shell: Color
    let panel: Color
    let paper: Color
    let subtlePaper: Color
    let line: Color
    let text: Color
    let secondaryText: Color
    let mutedText: Color
    let accent: Color
    let button: Color
    let selected: Color

    static let all: [MobileTheme] = [
        MobileTheme(id: "plain", name: "素笺", shell: Color(red: 0.97, green: 0.96, blue: 0.93), panel: Color(red: 1.00, green: 0.99, blue: 0.96), paper: .white, subtlePaper: Color(red: 0.98, green: 0.96, blue: 0.91), line: Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.42), text: Color(red: 0.12, green: 0.11, blue: 0.09), secondaryText: Color(red: 0.44, green: 0.39, blue: 0.32), mutedText: Color(red: 0.62, green: 0.57, blue: 0.48), accent: Color(red: 0.17, green: 0.47, blue: 0.48), button: Color(red: 1.00, green: 0.99, blue: 0.96), selected: Color(red: 0.83, green: 0.91, blue: 0.91)),
        MobileTheme(id: "apricot", name: "杏笺", shell: Color(red: 0.98, green: 0.93, blue: 0.80), panel: Color(red: 1.00, green: 0.96, blue: 0.86), paper: Color(red: 1.00, green: 0.95, blue: 0.82), subtlePaper: Color(red: 0.96, green: 0.88, blue: 0.70), line: Color(red: 0.72, green: 0.56, blue: 0.34).opacity(0.34), text: Color(red: 0.16, green: 0.11, blue: 0.07), secondaryText: Color(red: 0.48, green: 0.34, blue: 0.22), mutedText: Color(red: 0.64, green: 0.49, blue: 0.33), accent: Color(red: 0.62, green: 0.34, blue: 0.12), button: Color(red: 1.00, green: 0.96, blue: 0.86), selected: Color(red: 0.88, green: 0.72, blue: 0.50)),
        MobileTheme(id: "bamboo", name: "竹青", shell: Color(red: 0.89, green: 0.95, blue: 0.90), panel: Color(red: 0.95, green: 0.98, blue: 0.94), paper: Color(red: 0.96, green: 0.99, blue: 0.95), subtlePaper: Color(red: 0.86, green: 0.93, blue: 0.86), line: Color(red: 0.42, green: 0.62, blue: 0.48).opacity(0.32), text: Color(red: 0.08, green: 0.16, blue: 0.12), secondaryText: Color(red: 0.28, green: 0.45, blue: 0.34), mutedText: Color(red: 0.46, green: 0.58, blue: 0.48), accent: Color(red: 0.12, green: 0.45, blue: 0.33), button: Color(red: 0.95, green: 0.98, blue: 0.94), selected: Color(red: 0.76, green: 0.88, blue: 0.79)),
        MobileTheme(id: "night", name: "玄夜", shell: Color(red: 0.05, green: 0.06, blue: 0.07), panel: Color(red: 0.11, green: 0.12, blue: 0.14), paper: Color(red: 0.08, green: 0.08, blue: 0.09), subtlePaper: Color(red: 0.15, green: 0.15, blue: 0.17), line: Color.white.opacity(0.16), text: Color(red: 0.94, green: 0.93, blue: 0.90), secondaryText: Color(red: 0.74, green: 0.75, blue: 0.76), mutedText: Color(red: 0.55, green: 0.57, blue: 0.60), accent: Color(red: 0.55, green: 0.76, blue: 0.98), button: Color(red: 0.15, green: 0.16, blue: 0.18), selected: Color(red: 0.20, green: 0.32, blue: 0.46)),
        MobileTheme(id: "sea", name: "藏海", shell: Color(red: 0.04, green: 0.10, blue: 0.18), panel: Color(red: 0.08, green: 0.16, blue: 0.27), paper: Color(red: 0.06, green: 0.12, blue: 0.22), subtlePaper: Color(red: 0.10, green: 0.20, blue: 0.32), line: Color(red: 0.62, green: 0.74, blue: 0.88).opacity(0.20), text: Color(red: 0.94, green: 0.96, blue: 0.98), secondaryText: Color(red: 0.70, green: 0.79, blue: 0.88), mutedText: Color(red: 0.48, green: 0.60, blue: 0.72), accent: Color(red: 0.55, green: 0.73, blue: 0.96), button: Color(red: 0.10, green: 0.19, blue: 0.31), selected: Color(red: 0.16, green: 0.32, blue: 0.50))
    ]

    static func byId(_ id: String) -> MobileTheme {
        all.first { $0.id == id } ?? all[0]
    }
}

private func mobileTapFeedback() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

private func mobileWritingUIFont(size: CGFloat) -> UIFont {
    let preferredNames = [
        "Songti SC",
        "STSongti-SC-Regular",
        "STSongti-SC-Light",
        "SongtiSC-Regular"
    ]
    for name in preferredNames {
        if let font = UIFont(name: name, size: size) {
            return font
        }
    }
    return UIFont.systemFont(ofSize: size, weight: .regular)
}

private func mobileWritingFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    .custom("Songti SC", size: size).weight(weight)
}

final class MobileTextBuffer: ObservableObject {
    var text: String
    var hasChanges = false

    init(_ text: String = "") {
        self.text = text
    }
}

struct MobileWritingTextView: UIViewRepresentable {
    let buffer: MobileTextBuffer
    let theme: MobileTheme
    var fontSize: CGFloat = 22
    var horizontalInset: CGFloat = 30
    var topInset: CGFloat = 34
    var bottomInset: CGFloat = 90
    var lineSpacing: CGFloat = 13
    var paragraphSpacing: CGFloat = 24
    var onTextChange: (String) -> Void = { _ in }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.autocorrectionType = .default
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.backgroundColor = .clear
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.text = buffer.text
        applyStyle(to: textView, context: context)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        if textView.text != buffer.text, !textView.isFirstResponder {
            textView.text = buffer.text
            context.coordinator.lastStyleKey = ""
        }
        applyStyle(to: textView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private var styleKey: String {
        "\(theme.id)-\(fontSize)-\(horizontalInset)-\(topInset)-\(bottomInset)-\(lineSpacing)-\(paragraphSpacing)"
    }

    private func applyStyle(to textView: UITextView, context: Context) {
        let font = mobileWritingUIFont(size: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacing = paragraphSpacing
        paragraphStyle.alignment = .natural
        paragraphStyle.lineBreakMode = .byWordWrapping

        let foreground = UIColor(theme.text)
        textView.font = font
        textView.textColor = foreground
        textView.tintColor = UIColor(theme.accent)
        textView.backgroundColor = UIColor(theme.paper)
        textView.textContainerInset = UIEdgeInsets(top: topInset, left: horizontalInset, bottom: bottomInset, right: horizontalInset)
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraphStyle
        ]

        guard context.coordinator.lastStyleKey != styleKey else { return }
        let selectedRange = textView.selectedRange
        let attributed = NSMutableAttributedString(string: textView.text ?? "")
        attributed.addAttributes([
            .font: font,
            .foregroundColor: foreground,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: attributed.length))
        textView.attributedText = attributed
        textView.selectedRange = NSRange(location: min(selectedRange.location, attributed.length), length: min(selectedRange.length, max(0, attributed.length - min(selectedRange.location, attributed.length))))
        context.coordinator.lastStyleKey = styleKey
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MobileWritingTextView
        var lastStyleKey = ""
        private var notifyTask: Task<Void, Never>?

        init(_ parent: MobileWritingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""
            parent.buffer.text = currentText
            parent.buffer.hasChanges = true
            notifyTask?.cancel()
            notifyTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled, let self else { return }
                await MainActor.run {
                    self.parent.onTextChange(currentText)
                }
            }
        }

        deinit {
            notifyTask?.cancel()
        }
    }
}

private func mobileChapterLabel(_ chapter: MobileChapter) -> String {
    chapter.chapterNumber > 0 ? "第 \(chapter.chapterNumber) 章" : "章节"
}

private func countMobileWords(_ text: String) -> Int {
    text.filter { !$0.isWhitespace }.count
}

extension Notification.Name {
    static let mobileChapterDidSave = Notification.Name("xuanxuan.mobileChapterDidSave")
}

struct MobileBookshelfView: View {
    @StateObject private var model = MobileStore()
    @AppStorage("xuanxuan.mobileThemeId") private var themeId = "plain"
    @State private var showingNewProject = false
    @State private var showingFolderPicker = false
    @State private var projectToDelete: WritingProject?

    private var theme: MobileTheme { MobileTheme.byId(themeId) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.shell.ignoresSafeArea()
                VStack(spacing: 16) {
                    MobileBookshelfHeader(theme: theme, syncState: model.syncState, connectAction: { showingFolderPicker = true }, disconnectAction: { model.disconnectFolder() })

                    if model.projects.isEmpty {
                        MobileEmptyBookshelf(theme: theme, connectAction: { showingFolderPicker = true }, createAction: { showingNewProject = true })
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 20)], spacing: 28) {
                                ForEach(model.projects) { project in
                                    NavigationLink {
                                        MobileProjectView(project: project, store: model.store, theme: theme)
                                    } label: {
                                        MobileBookCover(project: project, summary: model.summaries[project.id] ?? ProjectSummary(), theme: theme)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            projectToDelete = project
                                        } label: {
                                            Label("删除小说", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                            .padding(.bottom, 30)
                        }
                        .refreshable { model.refreshFromICloud() }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ThemeMenu(themeId: $themeId, theme: theme)
                    Button {
                        mobileTapFeedback()
                        showingNewProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(theme.accent)
            .alert("删除小说？", isPresented: Binding(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } })) {
                Button("取消", role: .cancel) { projectToDelete = nil }
                Button("移到废纸篓", role: .destructive) {
                    if let project = projectToDelete {
                        model.deleteProject(project)
                    }
                    projectToDelete = nil
                }
            } message: {
                Text("会把作品文件夹移到废纸篓，并从书架移除。可从文件 App 或 Mac 废纸篓找回。")
            }
            .sheet(isPresented: $showingNewProject) {
                NewProjectSheet(theme: theme) { name in
                    model.createProject(named: name)
                    showingNewProject = false
                }
            }
            .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
                model.connectFolder(result)
            }
            .overlay(alignment: .bottom) {
                if !model.errorText.isEmpty {
                    Text(model.errorText)
                        .font(.caption)
                        .foregroundStyle(theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.panel.opacity(0.96), in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .task { model.boot() }
        }
    }
}

struct MobileBookshelfHeader: View {
    let theme: MobileTheme
    let syncState: MobileSyncState
    let connectAction: () -> Void
    let disconnectAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("萱萱写作 · 演示")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.text)
                    Text("随手码字，回到 Mac 继续写")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Menu {
                    Button("连接 iCloud 文件夹", action: connectAction)
                    if case .connected = syncState {
                        Button("断开连接", role: .destructive, action: disconnectAction)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: syncState.systemImage)
                        Text(syncState.title)
                            .lineLimit(1)
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.subtlePaper, in: Capsule())
                    .overlay(Capsule().stroke(theme.line))
                }
            }

            Text(syncState.detail)
                .font(.caption2)
                .foregroundStyle(theme.mutedText)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

struct MobileEmptyBookshelf: View {
    let theme: MobileTheme
    let connectAction: () -> Void
    let createAction: () -> Void

    var body: some View {
        Spacer()
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44))
                .foregroundStyle(theme.accent)
            Text("还没有作品")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.text)
            Text("可以连接 iCloud Drive 里的“萱萱写作”文件夹，也可以先在手机上新建一本。")
                .font(.callout)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            Button("连接 iCloud 文件夹", action: connectAction)
                .buttonStyle(.borderedProminent)
            Button("新建本机作品", action: createAction)
                .buttonStyle(.bordered)
        }
        .padding(24)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.line))
        .padding(24)
        Spacer()
    }
}

struct ThemeMenu: View {
    @Binding var themeId: String
    let theme: MobileTheme

    var body: some View {
        Menu {
            ForEach(MobileTheme.all) { item in
                Button {
                    themeId = item.id
                } label: {
                    Label(item.name, systemImage: item.id == themeId ? "checkmark" : "circle")
                }
            }
        } label: {
            Text(theme.name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(theme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.button, in: Capsule())
                .overlay(Capsule().stroke(theme.line))
        }
    }
}

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let theme: MobileTheme
    let onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("作品名") {
                    TextField("比如：不作洛神", text: $name)
                }
            }
            .navigationTitle("新建作品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { onCreate(name) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(theme.accent)
        }
    }
}

struct MobileBookCover: View {
    let project: WritingProject
    let summary: ProjectSummary
    let theme: MobileTheme

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                if let coverPath = project.coverImagePath, let image = UIImage(contentsOfFile: coverPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(theme.subtlePaper)
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(theme.accent.opacity(0.42))
                            .frame(width: 13)
                        Rectangle()
                            .fill(theme.line.opacity(0.24))
                            .frame(width: 1)
                        Spacer()
                    }
                    Text(project.name)
                        .font(mobileWritingFont(size: 17, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 18)
                }
                RoundedRectangle(cornerRadius: 9)
                    .stroke(theme.line)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .aspectRatio(2/3, contentMode: .fit)
            .shadow(color: .black.opacity(theme.id == "night" || theme.id == "sea" ? 0.28 : 0.11), radius: 9, y: 5)

            Text(project.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Text("\(summary.chapterCount) 章 · \(summary.totalWords) 字")
                .font(.caption)
                .foregroundStyle(theme.mutedText)
        }
    }
}

struct MobileProjectView: View {
    let project: WritingProject
    let store: ICloudWritingStore
    let theme: MobileTheme

    var body: some View {
        TabView {
            MobileChapterListView(project: project, store: store, theme: theme)
                .tabItem { Label("章节", systemImage: "doc.text") }
            MobileRelatedListView(project: project, store: store, theme: theme)
                .tabItem { Label("相关", systemImage: "folder") }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(theme.accent)
    }
}

struct MobilePaperSectionTitle: View {
    let title: String
    let theme: MobileTheme

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.top, 6)
            .padding(.bottom, 8)
    }
}

struct MobileContinueBookmark: View {
    let chapter: MobileChapter
    let theme: MobileTheme

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(theme.accent)
                .frame(width: 3)
                .clipShape(Capsule())
            VStack(alignment: .leading, spacing: 7) {
                Text("继续写 · \(mobileChapterLabel(chapter))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                Text(chapter.title)
                    .font(mobileWritingFont(size: 22, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text("\(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(theme.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.mutedText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(theme.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line))
    }
}

struct MobileChapterPaperRow: View {
    let chapter: MobileChapter
    let theme: MobileTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(mobileChapterLabel(chapter))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(chapter.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(2)
                Text("\(chapter.wordCount) 字")
                    .font(.caption)
                    .foregroundStyle(theme.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedText.opacity(0.75))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct MobileChapterListView: View {
    let project: WritingProject
    let store: ICloudWritingStore
    let theme: MobileTheme
    @State private var chapters: [MobileChapter] = []
    @State private var errorText = ""
    @State private var selectedChapter: MobileChapter?

    var body: some View {
        ZStack {
            theme.shell.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let next = chapters.first {
                        NavigationLink {
                            MobileChapterEditorView(project: project, chapter: next, store: store, theme: theme)
                        } label: {
                            MobileContinueBookmark(chapter: next, theme: theme)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { mobileTapFeedback() })
                        .padding(.bottom, 20)
                    }

                    if !chapters.isEmpty {
                        MobilePaperSectionTitle(title: "章节", theme: theme)
                        VStack(spacing: 0) {
                            ForEach(chapters) { chapter in
                                NavigationLink {
                                    MobileChapterEditorView(project: project, chapter: chapter, store: store, theme: theme)
                                } label: {
                                    MobileChapterPaperRow(chapter: chapter, theme: theme)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded { mobileTapFeedback() })
                                if chapter.id != chapters.last?.id {
                                    Divider().overlay(theme.line)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(theme.panel.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.line.opacity(0.82)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .refreshable { reload() }
        }
        .overlay {
            if chapters.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 34))
                        .foregroundStyle(theme.accent)
                    Text("暂无章节")
                        .font(.headline)
                        .foregroundStyle(theme.text)
                    Text(errorText.isEmpty ? "先建第一章，就可以在手机上随手写了。" : errorText)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                    Button("新建第一章") { createChapter() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.line))
                .padding(24)
            }
        }
        .toolbar {
            Button {
                mobileTapFeedback()
                createChapter()
            } label: {
                Label("新章", systemImage: "plus")
            }
        }
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .mobileChapterDidSave)) { notification in
            guard
                let projectId = notification.userInfo?["projectId"] as? String,
                projectId == project.id,
                let updated = notification.userInfo?["chapter"] as? MobileChapter
            else { return }
            if let index = chapters.firstIndex(where: { $0.id == updated.id }) {
                chapters[index] = updated
            }
        }
    }

    private func reload() {
        do {
            chapters = try store.listChapters(project: project)
            errorText = ""
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func createChapter() {
        do {
            _ = try store.createChapter(project: project)
            reload()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct MobileChapterEditorView: View {
    let project: WritingProject
    @State var chapter: MobileChapter
    let store: ICloudWritingStore
    let theme: MobileTheme
    @State private var savedText = "已打开"
    @State private var wordCount: Int
    @State private var hasUnsavedChanges = false
    @State private var autoSaveTask: Task<Void, Never>?
    @StateObject private var bodyBuffer: MobileTextBuffer

    init(project: WritingProject, chapter: MobileChapter, store: ICloudWritingStore, theme: MobileTheme) {
        self.project = project
        self._chapter = State(initialValue: chapter)
        self.store = store
        self.theme = theme
        self._wordCount = State(initialValue: chapter.wordCount)
        self._bodyBuffer = StateObject(wrappedValue: MobileTextBuffer(chapter.body))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(mobileChapterLabel(chapter))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 18)
                .background(theme.paper)
            TextField("章节标题", text: $chapter.title)
                .font(mobileWritingFont(size: 19, weight: .semibold))
                .foregroundStyle(theme.text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 30)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background(theme.paper)
            ZStack(alignment: .bottom) {
                MobileWritingTextView(
                    buffer: bodyBuffer,
                    theme: theme,
                    fontSize: 22,
                    horizontalInset: 30,
                    topInset: 34,
                    bottomInset: 108,
                    lineSpacing: 13,
                    paragraphSpacing: 26,
                    onTextChange: { text in
                        wordCount = countMobileWords(text)
                        scheduleAutoSave()
                    }
                )
                HStack(spacing: 10) {
                    Text("\(wordCount) 字")
                    Circle()
                        .fill(theme.secondaryText.opacity(0.35))
                        .frame(width: 4, height: 4)
                    Text(savedText)
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(theme.subtlePaper.opacity(0.78), in: Capsule())
                .overlay(Capsule().stroke(theme.line))
                .padding(.bottom, 16)
            }
        }
        .background(theme.paper)
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("保存") {
                mobileTapFeedback()
                saveNow(force: true)
            }
        }
        .tint(theme.accent)
        .onChange(of: chapter.title) { _, _ in
            scheduleAutoSave()
        }
        .onDisappear {
            saveNow(force: false)
        }
    }

    private func scheduleAutoSave() {
        hasUnsavedChanges = true
        savedText = "未保存"
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { saveDraft(cancelPending: false) }
        }
    }

    private func saveNow(force: Bool) {
        saveDraft(cancelPending: true, force: force)
    }

    private func saveDraft(cancelPending: Bool, force: Bool = false) {
        guard force || hasUnsavedChanges || bodyBuffer.hasChanges else { return }
        if cancelPending {
            autoSaveTask?.cancel()
            autoSaveTask = nil
        }

        let body = bodyBuffer.text
        var draft = chapter
        draft.body = body
        draft.wordCount = countMobileWords(body)
        savedText = "正在保存"
        let activeStore = store
        let activeProject = project
        let draftToSave = draft

        Task {
            do {
                try await Task.detached {
                    try activeStore.saveChapter(draftToSave, project: activeProject)
                }.value
                await MainActor.run {
                    chapter = draftToSave
                    wordCount = draftToSave.wordCount
                    hasUnsavedChanges = false
                    bodyBuffer.hasChanges = false
                    savedText = "已保存"
                    NotificationCenter.default.post(
                        name: .mobileChapterDidSave,
                        object: nil,
                        userInfo: ["projectId": activeProject.id, "chapter": draftToSave]
                    )
                }
            } catch {
                await MainActor.run {
                    savedText = "保存失败"
                }
            }
        }
    }
}

struct MobileRelatedListView: View {
    let project: WritingProject
    let store: ICloudWritingStore
    let theme: MobileTheme
    @State private var docs: [RelatedDoc] = []
    @State private var errorText = ""
    @State private var showingNewDoc = false

    var body: some View {
        ZStack {
            theme.shell.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(Dictionary(grouping: docs, by: \.category).keys.sorted(), id: \.self) { category in
                        VStack(alignment: .leading, spacing: 0) {
                            MobilePaperSectionTitle(title: category, theme: theme)
                            VStack(spacing: 0) {
                                let categoryDocs = docs.filter { $0.category == category }
                                ForEach(categoryDocs) { doc in
                                    NavigationLink {
                                        MobileRelatedEditorView(project: project, doc: doc, store: store, theme: theme)
                                    } label: {
                                        MobileRelatedPaperRow(doc: doc, theme: theme)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded { mobileTapFeedback() })
                                    if doc.id != categoryDocs.last?.id {
                                        Divider().overlay(theme.line)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(theme.panel, in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.line))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .refreshable { reload() }
        }
        .overlay {
            if docs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 34))
                        .foregroundStyle(theme.accent)
                    Text("暂无相关资料")
                        .font(.headline)
                        .foregroundStyle(theme.text)
                    Text(errorText.isEmpty ? "可以新建设定、大纲、角色或灵感资料。" : errorText)
                        .font(.callout)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.line))
                .padding(24)
            }
        }
        .toolbar {
            Button {
                mobileTapFeedback()
                showingNewDoc = true
            } label: {
                Label("新资料", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingNewDoc) {
            NewRelatedDocSheet(theme: theme) { title, category, fileKind in
                do {
                    _ = try store.createRelatedDoc(project: project, title: title, category: category, fileKind: fileKind)
                    reload()
                    showingNewDoc = false
                } catch {
                    errorText = error.localizedDescription
                }
            }
        }
        .task { reload() }
    }

    private func reload() {
        do {
            docs = try store.listRelatedDocs(project: project)
            errorText = ""
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct MobileRelatedPaperRow: View {
    let doc: RelatedDoc
    let theme: MobileTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "doc.text")
                .font(.callout)
                .foregroundStyle(theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(doc.fileKind.badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(doc.fileKind == .text ? theme.accent : theme.secondaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(theme.subtlePaper, in: RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.line))
                    Text(doc.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                }
                Text(doc.category)
                    .font(.caption)
                    .foregroundStyle(theme.mutedText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.mutedText.opacity(0.75))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

struct NewRelatedDocSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "灵感记录"
    @State private var fileKind: RelatedDocFileKind = .markdown
    let theme: MobileTheme
    let categories = ["作品设定", "作品大纲", "角色设定", "灵感记录", "导入资料"]
    let onCreate: (String, String, RelatedDocFileKind) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("资料") {
                    TextField("标题", text: $title)
                    Picker("分类", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    Picker("格式", selection: $fileKind) {
                        ForEach(RelatedDocFileKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                }
            }
            .navigationTitle("新建资料")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") { onCreate(title, category, fileKind) }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .tint(theme.accent)
        }
    }
}

struct MobileRelatedEditorView: View {
    let project: WritingProject
    @State var doc: RelatedDoc
    let store: ICloudWritingStore
    let theme: MobileTheme
    @State private var savedText = "已打开"
    @State private var wordCount: Int
    @State private var hasUnsavedChanges = false
    @State private var autoSaveTask: Task<Void, Never>?
    @StateObject private var bodyBuffer: MobileTextBuffer

    init(project: WritingProject, doc: RelatedDoc, store: ICloudWritingStore, theme: MobileTheme) {
        self.project = project
        self._doc = State(initialValue: doc)
        self.store = store
        self.theme = theme
        self._wordCount = State(initialValue: countMobileWords(doc.body))
        self._bodyBuffer = StateObject(wrappedValue: MobileTextBuffer(doc.body))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MobileWritingTextView(
                buffer: bodyBuffer,
                theme: theme,
                fontSize: 21,
                horizontalInset: 30,
                topInset: 42,
                bottomInset: 108,
                lineSpacing: 13,
                paragraphSpacing: 24,
                onTextChange: { text in
                    wordCount = countMobileWords(text)
                    scheduleAutoSave()
                }
            )
            HStack(spacing: 10) {
                Text("\(wordCount) 字")
                Circle()
                    .fill(theme.secondaryText.opacity(0.35))
                    .frame(width: 4, height: 4)
                Text(savedText)
            }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(theme.subtlePaper.opacity(0.78), in: Capsule())
                .overlay(Capsule().stroke(theme.line))
                .padding(.bottom, 16)
        }
        .background(theme.paper)
        .navigationTitle(doc.title)
        .toolbar {
            Button("保存") {
                mobileTapFeedback()
                saveNow(force: true)
            }
        }
        .tint(theme.accent)
        .onDisappear {
            saveNow(force: false)
        }
    }

    private func scheduleAutoSave() {
        hasUnsavedChanges = true
        savedText = "未保存"
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { saveDraft(cancelPending: false) }
        }
    }

    private func saveNow(force: Bool) {
        saveDraft(cancelPending: true, force: force)
    }

    private func saveDraft(cancelPending: Bool, force: Bool = false) {
        guard force || hasUnsavedChanges || bodyBuffer.hasChanges else { return }
        if cancelPending {
            autoSaveTask?.cancel()
            autoSaveTask = nil
        }

        var draft = doc
        draft.body = bodyBuffer.text
        savedText = "正在保存"
        let activeStore = store
        let activeProject = project
        let draftToSave = draft

        Task {
            do {
                try await Task.detached {
                    try activeStore.saveRelatedDoc(draftToSave, project: activeProject)
                }.value
                await MainActor.run {
                    doc = draftToSave
                    wordCount = countMobileWords(draftToSave.body)
                    hasUnsavedChanges = false
                    bodyBuffer.hasChanges = false
                    savedText = "已保存"
                }
            } catch {
                await MainActor.run {
                    savedText = "保存失败"
                }
            }
        }
    }
}
