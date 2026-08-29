import Foundation


enum PatchWorkspaceService {
    private struct Manifest: Codable {
        let schemaVersion: Int
        let projectID: UUID
        var displayName: String
    }


    private static let manifestFilename = ".3105-project.plist"
    private static let manifestSchemaVersion = 1


    /// Private root for patch workspaces. It intentionally lives outside Documents so iOS Files
    /// does not expose the patch packages or their editable workspace.
    static func documentsRootURL(fileManager: FileManager = .default) throws -> URL {
        try privateRootURL(fileManager: fileManager)
    }

    private static func privateRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchWorkspace", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func patchesRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try privateRootURL(fileManager: fileManager)
            .appendingPathComponent("Patches", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        migrateLegacyDocumentsWorkspace(to: root, fileManager: fileManager)
        return root
    }

    private static func migrateLegacyDocumentsWorkspace(
        to privateRoot: URL,
        fileManager: FileManager
    ) {
        guard let documents = try? fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }
        let legacyRoot = documents.appendingPathComponent("Patches", isDirectory: true)
        guard fileManager.fileExists(atPath: legacyRoot.path) else { return }
        guard let children = try? fileManager.contentsOfDirectory(
            at: legacyRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            let destination = privateRoot.appendingPathComponent(child.lastPathComponent, isDirectory: false)
            if fileManager.fileExists(atPath: destination.path) {
                try? fileManager.removeItem(at: child)
            } else {
                try? fileManager.moveItem(at: child, to: destination)
            }
        }
        try? fileManager.removeItem(at: legacyRoot)
    }

    static func createWorkspace(
        for project: PatchProject,
        patchesRoot: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        try PatchPackageCodec.validate(project)
        let root = try patchesRoot ?? patchesRootURL(fileManager: fileManager)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        if let existing = workspaceURL(
            projectID: project.id,
            patchesRoot: root,
            fileManager: fileManager
        ) {
            return existing
        }


        let destination = uniqueWorkspaceURL(
            named: project.name,
            in: root,
            fileManager: fileManager
        )
        let staging = root.appendingPathComponent(
            ".3105-workspace-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? fileManager.removeItem(at: staging) }


        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
            for bundleID in project.allBundleIdentifiers {
                let canonical = try PatchPathValidator.canonicalBundleIdentifier(bundleID)
                guard canonical == bundleID else { throw PatchPackageError.invalidProject }
                try fileManager.createDirectory(
                    at: staging.appendingPathComponent(bundleID, isDirectory: true),
                    withIntermediateDirectories: false
                )
            }
            for directory in project.directories {
                let target = try workspaceTarget(
                    bundleID: directory.bundleID,
