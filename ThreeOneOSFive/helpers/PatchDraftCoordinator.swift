import Foundation

struct PatchDraftRequest: Identifiable {
    let id = UUID()
    let draft: PatchProjectDraft
}

enum PatchImportSource: Equatable {
    case file(URL)
    case invalid
}

enum PatchImportRoute {
    static let urlScheme = "threeoneosfive"

    static func resolve(_ incomingURL: URL) -> PatchImportSource {
        guard incomingURL.isFileURL else { return .invalid }
        return incomingURL.pathExtension.lowercased() == "3105"
            ? .file(incomingURL)
            : .invalid
    }
}

struct PatchImportRequest: Identifiable, Equatable {
    let id = UUID()
    let source: PatchImportSource
}

@MainActor
final class PatchDraftCoordinator: ObservableObject {
    @Published var request: PatchDraftRequest?
    @Published var importRequest: PatchImportRequest?

    func present(_ draft: PatchProjectDraft) {
        request = PatchDraftRequest(draft: draft)
    }

    func clear() {
        request = nil
    }

    func presentImport(_ url: URL) {
        importRequest = PatchImportRequest(source: PatchImportRoute.resolve(url))
    }

    func clearImport() {
        importRequest = nil
    }
}
