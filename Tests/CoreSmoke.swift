import Foundation

@main
struct CoreSmoke {
    static func main() throws {
        let store = ICloudWritingStore()
        let projects = try store.loadProjects()
        precondition(projects.count == 1 && projects[0].id == "lighthouse-demo")
        let project = projects[0]
        let chapters = try store.listChapters(project: project)
        precondition(chapters.count == 3)
        var edited = chapters[0]
        edited.body += "\nCORE_ROUNDTRIP"
        try store.saveChapter(edited, project: project)
        let saved = try ICloudWritingStore().listChapters(project: project)
        precondition(saved[0].body.contains("CORE_ROUNDTRIP"))
        precondition(saved[0].chapterNumber == chapters[0].chapterNumber)
        let docs = try store.listRelatedDocs(project: project)
        precondition(docs.contains { $0.fileKind == .text })
        let selected = ICloudWritingStore(rootURL: store.rootURL.appendingPathComponent("selected-empty"))
        let selectedProjects = try selected.loadProjects()
        precondition(selectedProjects.isEmpty, "Explicit roots must not receive the local demo automatically")
        print("PASS shared core: fictional bootstrap, chapter roundtrip, metadata, TXT discovery")
    }
}
