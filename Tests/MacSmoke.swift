import AppKit
import Foundation

@main
struct MacSmoke {
    static func main() throws {
        _ = NSApplication.shared
        let service = FileService()
        let projects = try service.loadProjects()
        precondition(projects.count == 1 && projects[0].id == "lighthouse-demo")
        let project = projects[0]
        precondition(project.path.hasPrefix(appSupportRoot.path + "/projects/"))
        let chapters = try service.listChapters(project: project)
        precondition(chapters.count == 3)
        let original = chapters[0]
        try service.saveChapter(project: project, fileName: original.fileName, meta: original.meta, body: original.body + "\nSAVE_ROUNDTRIP")
        let reread = try service.readChapter(project: project, fileName: original.fileName)
        precondition(reread.body.contains("SAVE_ROUNDTRIP"))
        try service.saveChapter(project: project, fileName: original.fileName, meta: original.meta, body: original.body)
        let docs = try service.listRelatedDocs(project: project)
        precondition(docs.contains { $0.fileKind == .text })
        let txt = docs.first { $0.fileKind == .text }!
        let before = try service.readRelatedDoc(project: project, doc: txt)
        try service.saveRelatedDoc(project: project, doc: txt, body: before.body + "\nTXT_ROUNDTRIP")
        let updatedTXT = try service.readRelatedDoc(project: project, doc: txt)
        precondition(updatedTXT.body.contains("TXT_ROUNDTRIP"))
        try service.saveRelatedDoc(project: project, doc: txt, body: before.body)
        let matches = rangesForFind("收音机", in: original.body, options: FindReplaceOptions())
        precondition(matches.count == 1)
        let imageURL = appSupportRoot.appendingPathComponent("export.png")
        try service.exportChapterImage(title: original.meta.title, body: original.body, settings: .defaults, to: imageURL)
        precondition(NSImage(contentsOf: imageURL) != nil)
        // Imported registries must never retain paths pointing outside the selected root.
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: service.registryFileURL)) as! [String: Any]
        var entries = object["projects"] as! [[String: Any]]
        entries[0]["path"] = "/unselected-private-location/lighthouse-demo"
        object["projects"] = entries
        try JSONSerialization.data(withJSONObject: object).write(to: service.registryFileURL)
        let normalized = try service.loadProjects()
        precondition(normalized[0].path == project.path)
        var selectedSettings = AppSettings.defaults
        selectedSettings.syncEnabled = true
        selectedSettings.syncRootPath = appSupportRoot.appendingPathComponent("selected-empty").path
        let selectedProjects = try FileService(settings: selectedSettings).loadProjects()
        precondition(selectedProjects.isEmpty, "Selecting an empty root must not merge local projects")
        let dataBefore = try Data(contentsOf: service.registryFileURL)
        _ = try FileService().loadProjects()
        let dataAfter = try Data(contentsOf: service.registryFileURL)
        precondition(dataAfter == dataBefore)
        print("PASS Mac: fictional bootstrap, chapter/TXT roundtrip, search, PNG export, root isolation, repeat startup")
    }
}
