import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct BookshelfView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center) {
                HStack(alignment: .center, spacing: 14) {
                    AppLogoMark(size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appDisplayName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(store.settings.primaryTextColor)
                        Text(store.settings.syncEnabled ? "iCloud Drive 同步" : "本机书房")
                            .font(.caption)
                            .foregroundColor(store.settings.secondaryTextColor)
                    }
                }
                Spacer()
                Button("新建作品") { store.showingNewProject = true }
                    .buttonStyle(PrimaryButtonStyle())
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 26)], spacing: 34) {
                    ForEach(store.projects) { project in
                        ProjectCard(project: project)
                            .onTapGesture { store.openProject(project) }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 32)
        .background(store.settings.appBackgroundColor)
    }
}

struct AppLogoMark: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "book.closed.fill")
            .resizable()
            .scaledToFit()
            .padding(size * 0.2)
            .foregroundColor(Color.accentColor)
            .background(Color.accentSoft)
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
    }
}

struct ProjectCard: View {
    @EnvironmentObject var store: AppStore
    let project: WritingProject

    var stats: ProjectStats {
        let chapters = (try? FileService().listChapters(project: project)) ?? []
        return FileService().calculateStats(chapters: chapters, frequencyDays: project.frequencyDays)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .leading) {
                BookCoverView(project: project)
                Rectangle()
                    .fill(LinearGradient(colors: [.black.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 22)
            }
            .frame(width: 156, height: 234)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 8)
            .contextMenu {
                Button("编辑书名…") { store.beginEditProject(project) }
                Divider()
                Button("设置封面…") { store.chooseCover(for: project) }
                Button("移除封面") { store.removeCover(for: project) }
                    .disabled(project.coverImagePath == nil)
            }

            Text(project.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 156)
            Text("\(stats.totalChapters) 章 · \(stats.totalWords) 字 · \(stats.supportDays) 天存稿")
                .font(.caption2)
                .foregroundColor(store.settings.secondaryTextColor)
                .lineLimit(1)
                .frame(width: 178)
        }
        .frame(width: 180)
    }
}

struct BookCoverView: View {
    let project: WritingProject

    var body: some View {
        if let path = project.coverImagePath,
           FileManager.default.fileExists(atPath: path),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.93, green: 0.89, blue: 0.79), Color(red: 0.82, green: 0.75, blue: 0.60)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 16) {
                    Text(project.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(Color(red: 0.18, green: 0.13, blue: 0.08))
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .minimumScaleFactor(0.62)
                        .padding(.horizontal, 20)
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.13, blue: 0.08).opacity(0.28))
                        .frame(width: 64, height: 1)
                }
                HStack {
                    Text(String(project.name.prefix(6)))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.78))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(alignment: .leading) {
                    Rectangle()
                        .fill(Color(red: 0.28, green: 0.45, blue: 0.43).opacity(0.76))
                        .frame(width: 24)
                }
            }
        }
    }
}
