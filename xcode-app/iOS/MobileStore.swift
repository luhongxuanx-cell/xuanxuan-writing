import Foundation
import SwiftUI

enum MobileSyncState: Equatable {
    case local
    case syncing(URL)
    case connected(URL)
    case needsReconnect

    var title: String {
        switch self {
        case .local: return "本机"
        case .syncing: return "正在同步"
        case .connected: return "已连接 iCloud Drive"
        case .needsReconnect: return "需要重连"
        }
    }

    var detail: String {
        switch self {
        case .local:
            return "当前作品只保存在这台 iPhone"
        case .syncing(let url):
            return "正在等待 \(url.lastPathComponent) 里的作品文件"
        case .connected(let url):
            return url.lastPathComponent
        case .needsReconnect:
            return "请重新选择“萱萱写作”文件夹"
        }
    }

    var systemImage: String {
        switch self {
        case .local: return "iphone"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .connected: return "icloud"
        case .needsReconnect: return "exclamationmark.icloud"
        }
    }
}

@MainActor
final class MobileStore: ObservableObject {
    @Published var projects: [WritingProject] = []
    @Published var summaries: [String: ProjectSummary] = [:]
    @Published var errorText = ""
    @Published var syncState: MobileSyncState = .local

    private(set) var store: ICloudWritingStore = ICloudWritingStore()
    private var scopedFolder: ScopedFolderAccess?
    private var iCloudWarmupTask: Task<Void, Never>?
    private let bookmarkKey = "xuanxuan.demo.folderBookmark"
    private let fileManager = FileManager.default

    func boot() {
        restoreFolderAccess()
        if case .connected(let url) = syncState {
            reloadAfterICloudSettles(url: url)
        } else {
            reload()
        }
    }

    func reload() {
        do {
            if case .connected = syncState {
                try store.requestICloudDownloads()
            }
            let loadedProjects = try store.loadProjects()
            projects = loadedProjects
            summaries = loadedProjects.reduce(into: summaries) { result, project in
                if result[project.id] == nil {
                    result[project.id] = ProjectSummary()
                }
            }
            errorText = ""
            loadSummariesInBackground(for: loadedProjects)
        } catch {
            errorText = "无法读取作品：\(error.localizedDescription)"
        }
    }

    func refreshFromICloud() {
        if case .connected(let url) = syncState {
            reloadAfterICloudSettles(url: url)
        } else {
            reload()
        }
    }

    private func reloadAfterICloudSettles(url: URL) {
        iCloudWarmupTask?.cancel()
        let activeStore = store
        syncState = .syncing(url)
        errorText = ""
        iCloudWarmupTask = Task {
            let foundExistingFiles = await activeStore.warmUpICloudDrive()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.store === activeStore else { return }
                self.syncState = .connected(url)
                self.reload()
                if !foundExistingFiles && self.projects.isEmpty {
                    self.errorText = "iCloud 还没把作品文件同步下来，稍后可下拉刷新。"
                }
            }
        }
    }

    private func loadSummariesInBackground(for loadedProjects: [WritingProject]) {
        let activeStore = store
        Task.detached {
            var nextSummaries: [String: ProjectSummary] = [:]
            for project in loadedProjects {
                nextSummaries[project.id] = (try? activeStore.projectSummary(project)) ?? ProjectSummary()
            }
            let completedSummaries = nextSummaries
            await MainActor.run {
                let currentIds = Set(self.projects.map(\.id))
                for (projectId, summary) in completedSummaries where currentIds.contains(projectId) {
                    self.summaries[projectId] = summary
                }
            }
        }
    }

    func connectFolder(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let access = ScopedFolderAccess(url: url)
            guard access.start() else {
                syncState = .needsReconnect
                errorText = "无法访问这个文件夹，请重新选择。"
                return
            }
            let bookmark = try url.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            scopedFolder = access
            store = ICloudWritingStore(rootURL: url)
            syncState = .connected(url)
            reloadAfterICloudSettles(url: url)
        } catch {
            syncState = .needsReconnect
            errorText = "连接失败：\(error.localizedDescription)"
        }
    }

    func disconnectFolder() {
        iCloudWarmupTask?.cancel()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        scopedFolder = nil
        store = ICloudWritingStore()
        syncState = .local
        reload()
    }

    func createProject(named name: String) {
        do {
            _ = try store.createProject(name: name)
            reload()
        } catch {
            errorText = "新建失败：\(error.localizedDescription)"
        }
    }

    func deleteProject(_ project: WritingProject) {
        do {
            try store.deleteProjectMovingToTrash(project)
            reload()
        } catch {
            errorText = "删除失败：\(error.localizedDescription)"
        }
    }

    private func restoreFolderAccess() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            syncState = .local
            store = ICloudWritingStore()
            return
        }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            let access = ScopedFolderAccess(url: url)
            guard !stale, access.start() else {
                syncState = .needsReconnect
                store = ICloudWritingStore()
                return
            }
            scopedFolder = access
            store = ICloudWritingStore(rootURL: url)
            syncState = .connected(url)
        } catch {
            syncState = .needsReconnect
            store = ICloudWritingStore()
        }
    }


}

final class ScopedFolderAccess {
    let url: URL
    private var isAccessing = false

    init(url: URL) {
        self.url = url
    }

    func start() -> Bool {
        isAccessing = url.startAccessingSecurityScopedResource()
        return isAccessing || FileManager.default.isReadableFile(atPath: url.path)
    }

    deinit {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
