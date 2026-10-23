import SwiftUI
import AppKit
import CryptoKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        Group {
            if store.selectedProject == nil {
                BookshelfView()
            } else {
                WorkspaceView()
            }
        }
        .foregroundColor(store.settings.editorTextColor)
        .background(store.settings.appBackgroundColor)
        .onAppear { store.boot() }
        .sheet(isPresented: $store.showingNewProject) {
            NewProjectView()
                .environmentObject(store)
                .frame(width: 420)
        }
        .sheet(isPresented: $store.showingEditProject) {
            if let project = store.editingProject {
                EditProjectView(project: project)
                    .environmentObject(store)
                    .frame(width: 420)
            }
        }
        .sheet(isPresented: $store.showingNewChapter) {
            NewChapterView()
                .environmentObject(store)
                .frame(width: 380)
        }
        .sheet(isPresented: $store.showingNewRelatedDoc) {
            NewRelatedDocView()
                .environmentObject(store)
                .frame(width: 420)
        }
        .sheet(isPresented: $store.showingSyncSettings) {
            SyncSettingsView()
                .environmentObject(store)
                .frame(width: 520)
        }
        .sheet(isPresented: $store.showingPhonePreview) {
            PhonePreviewView(title: store.editorTitle, bodyText: store.editorBody)
                .environmentObject(store)
                .frame(width: 390, height: 760)
        }
        .sheet(isPresented: $store.showingFindReplace) {
            FindReplacePanel()
                .environmentObject(store)
                .frame(width: 520)
        }
        .sheet(isPresented: $store.showingCommandPalette) {
            CommandPaletteView()
                .environmentObject(store)
                .frame(width: 620, height: 620)
        }
    }
}
