import CryptoKit
import Foundation

struct RemotePatchManifest: Codable {
    struct Entry: Codable, Hashable {
        let filename: String
        let game: String
        let sizeBytes: Int
        let sha256: String
        let revision: Int
        let url: String
    }

    let schemaVersion: Int
    let manifestVersion: Int
    let generatedAt: String
    let maintenanceMode: Bool?
    let patches: [Entry]
}

enum PatchRemoteSyncError: LocalizedError {
    case invalidManifest
    case invalidPatchName
    case invalidSize
    case invalidHash
    case passwordProtectedRemotePatch
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidManifest: return "O manifesto remoto é inválido."
        case .invalidPatchName: return "O servidor retornou um nome de patch inválido."
        case .invalidSize: return "O tamanho do patch remoto não é permitido."
        case .invalidHash: return "A integridade SHA-256 do patch não confere."
        case .passwordProtectedRemotePatch: return "Patches remotos protegidos por senha precisam ser importados manualmente."
        case .unavailable: return "Não foi possível conectar ao servidor de patches."
        }
    }
}

enum PatchRemoteSync {
    // Public HTTPS endpoint of the PROXY SYSTEM Patch Panel.
    static let manifestURL = URL(string: "https://proxypatch-5pmh6tcn.manus.space/manifest.json")!
    static let maxPatchBytes = 25 * 1024 * 1024
    static let cachedManifestName = "remote-manifest.json"

    static func synchronize(fileManager: FileManager = .default) async throws -> Int {
        let root = try PatchProjectLibrary.packageRootURL(fileManager: fileManager)
        let cachedURL = root.appendingPathComponent(cachedManifestName)
        let oldManifest = try? loadManifest(at: cachedURL, fileManager: fileManager)

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 180
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let manifestData: Data
        do {
            var request = URLRequest(
                url: manifestURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw PatchRemoteSyncError.unavailable
            }
            manifestData = data
        } catch {
            if oldManifest != nil { return 0 }
            if let syncError = error as? PatchRemoteSyncError { throw syncError }
            throw PatchRemoteSyncError.unavailable
        }

        let manifest: RemotePatchManifest
        do {
            manifest = try JSONDecoder().decode(RemotePatchManifest.self, from: manifestData)
        } catch {
            throw PatchRemoteSyncError.invalidManifest
        }

        UserDefaults.standard.set(manifest.maintenanceMode ?? false, forKey: "proxy_system_patches_maintenance")

        let localItems = PatchProjectLibrary.load(fileManager: fileManager)
        let oldNames = Set(oldManifest?.patches.map(\.filename) ?? [])
        let newNames = Set(manifest.patches.map(\.filename))
        let newHashes = Set(manifest.patches.map(\.sha256))
        var changed = 0

        for entry in manifest.patches {
            guard entry.filename.lowercased().hasSuffix(".3105") else {
                throw PatchRemoteSyncError.invalidPatchName
            }
            guard entry.sizeBytes > 0, entry.sizeBytes <= maxPatchBytes else {
                throw PatchRemoteSyncError.invalidSize
            }

            let localURL = root.appendingPathComponent(entry.filename, isDirectory: false)
            if let matchingLocalURL = matchingLocalURL(
                for: entry,
                expectedURL: localURL,
                localItems: localItems,
                fileManager: fileManager
            ),
               let localData = try? PatchProjectLibrary.readPackage(at: matchingLocalURL),
               sha256(localData) == entry.sha256 {
                if matchingLocalURL.standardizedFileURL != localURL.standardizedFileURL {
                    try? localData.write(to: localURL, options: [.atomic, .completeFileProtection])
                    try? fileManager.removeItem(at: matchingLocalURL)
                }
                continue
            }

            guard let remoteURL = URL(string: entry.url, relativeTo: manifestURL)?.absoluteURL else {
                throw PatchRemoteSyncError.invalidManifest
            }

            var request = URLRequest(
                url: remoteURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 180
            )
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw PatchRemoteSyncError.unavailable
            }
            guard data.count == entry.sizeBytes, sha256(data) == entry.sha256 else {
                throw PatchRemoteSyncError.invalidHash
            }

            do {
                try PatchProjectLibrary.installRemotePackage(
                    data: data,
                    existingURL: fileManager.fileExists(atPath: localURL.path) ? localURL : nil,
                    destinationFilename: entry.filename,
                    fileManager: fileManager
                )
            } catch PatchPackageError.invalidProject {
                throw PatchRemoteSyncError.passwordProtectedRemotePatch
            }
            changed += 1
        }

        let removedNames = oldNames.subtracting(newNames)
        let removedHashes = Set(
            (oldManifest?.patches ?? [])
                .filter { removedNames.contains($0.filename) }
                .map(\.sha256)
        ).subtracting(newHashes)
        let currentLocalItems = PatchProjectLibrary.load(fileManager: fileManager)
        for item in currentLocalItems {
            let localHash = (try? PatchProjectLibrary.readPackage(at: item.packageURL)).map(sha256)
            let hasRemovedRemoteIdentity = removedNames.contains(item.packageURL.lastPathComponent)
            guard (localHash.map(removedHashes.contains) ?? false) || hasRemovedRemoteIdentity else { continue }
            try? PatchProjectLibrary.delete(item, fileManager: fileManager)
            changed += 1
        }

        // The manifest is not secret. Avoid completeFileProtection here so a sync
        // started while iOS data protection is transitioning cannot fail after a
        // successful network request.
        try manifestData.write(to: cachedURL, options: [.atomic])
        return changed
    }

    private static func matchingLocalURL(
        for entry: RemotePatchManifest.Entry,
        expectedURL: URL,
        localItems: [PatchLibraryItem],
        fileManager: FileManager
    ) -> URL? {
        if fileManager.fileExists(atPath: expectedURL.path) {
            return expectedURL
        }
        return localItems.first { item in
            guard let localData = try? PatchProjectLibrary.readPackage(at: item.packageURL) else { return false }
            return sha256(localData) == entry.sha256
        }?.packageURL
    }

    private static func loadManifest(at url: URL, fileManager: FileManager) throws -> RemotePatchManifest {
        guard fileManager.fileExists(atPath: url.path) else {
            throw PatchRemoteSyncError.invalidManifest
        }
        return try JSONDecoder().decode(
            RemotePatchManifest.self,
            from: Data(contentsOf: url, options: .mappedIfSafe)
        )
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
