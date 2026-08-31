import Foundation

struct RemotePatchManifest: Decodable {
    struct Theme: Decodable {
        let accentColor: String
    }
    struct Entry: Decodable {
        let id: Int
        let name: String
        let description: String
        let version: String
        let category: String
        let kind: String
        let character: String?
        let fileName: String
        let size: Int
        let downloadUrl: URL
        let iconUrl: URL?
    }
    let schemaVersion: Int
    let revision: String
    let theme: Theme?
    let revocations: [String]?
    let patches: [Entry]
}

enum PatchRemoteSyncError: LocalizedError {
    case unavailable(statusCode: Int)
    case invalidManifest
    case invalidPatch(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let statusCode): return "Servidor do catálogo respondeu HTTP \(statusCode)."
        case .invalidManifest: return "O manifesto do catálogo está inválido ou incompatível."
        case .invalidPatch(let fileName): return "O patch \(fileName) não passou na validação de segurança."
        }
    }
}

enum PatchRemoteSync {
    static let remoteRemovalVerification = "REMOTE_REMOVAL_TOMBSTONE|BUNDLED_REINSTALL_BLOCKED|REMOVE_ALL_UNPUBLISHED_PATCHES"
    static let manifestURL = URL(string: "https://patch3105-zrifekat.manus.space/api/v1/manifest.json")!
    static let themeURL = URL(string: "https://patch3105-zrifekat.manus.space/api/v1/theme.json")!
    private static let managedKey = "3105.managedRemotePatchFilenames"
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = true
        configuration.httpAdditionalHeaders = ["Accept": "application/json", "Cache-Control": "no-cache"]
        return URLSession(configuration: configuration)
    }()

    static func synchronizeTheme() async throws {
        var request = URLRequest(url: themeURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return }
        struct ThemeResponse: Decodable { let schemaVersion: Int; let accentColor: String }
        let theme = try JSONDecoder().decode(ThemeResponse.self, from: data)
        guard theme.schemaVersion == 1, theme.accentColor.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else { return }
        UserDefaults.standard.set(theme.accentColor.uppercased(), forKey: "3105_accent_color_hex")
    }

    static func synchronize() async throws -> Int {
        var request = URLRequest(url: manifestURL)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PatchRemoteSyncError.unavailable(statusCode: statusCode)
        }
        let manifest = try JSONDecoder().decode(RemotePatchManifest.self, from: data)
        guard manifest.schemaVersion == 1 else { throw PatchRemoteSyncError.invalidManifest }
        if let accentColor = manifest.theme?.accentColor, accentColor.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil {
            UserDefaults.standard.set(accentColor.uppercased(), forKey: "3105_accent_color_hex")
        }
        var managed = Set(UserDefaults.standard.stringArray(forKey: managedKey) ?? [])
        var active = Set<String>()
        var categories = UserDefaults.standard.dictionary(forKey: "3105.managedRemotePatchCategories") as? [String: String] ?? [:]
        var kinds = UserDefaults.standard.dictionary(forKey: "3105.managedRemotePatchKinds") as? [String: String] ?? [:]
        var characters = UserDefaults.standard.dictionary(forKey: "3105.managedRemotePatchCharacters") as? [String: String] ?? [:]
        var icons = UserDefaults.standard.dictionary(forKey: "3105.managedRemotePatchIcons") as? [String: String] ?? [:]
        var removedRemoteNames = Set(UserDefaults.standard.stringArray(forKey: "3105.remoteRemovedPatchFilenames") ?? [])
        var changed = 0
        let activeRemoteNames = Set(manifest.patches.map(\.fileName))
        for filename in Set(manifest.revocations ?? []).subtracting(activeRemoteNames) {
            try? PatchProjectLibrary.removeManagedPackage(named: filename)
            managed.remove(filename)
            categories.removeValue(forKey: filename)
            kinds.removeValue(forKey: filename)
            characters.removeValue(forKey: filename)
            if let iconPath = icons.removeValue(forKey: filename) { PatchProjectLibrary.removeRemoteIcon(named: URL(fileURLWithPath: iconPath).lastPathComponent) }
            removedRemoteNames.insert(filename)
            changed += 1
        }
        for entry in manifest.patches {
            guard ["normal", "max"].contains(entry.category), entry.downloadUrl.scheme?.lowercased() == "https", entry.downloadUrl.user == nil, entry.downloadUrl.password == nil, entry.fileName.lowercased().hasSuffix(".3105") else { throw PatchRemoteSyncError.invalidPatch(entry.fileName) }
            active.insert(entry.fileName)
            removedRemoteNames.remove(entry.fileName)
            let (packageData, packageResponse) = try await session.data(from: entry.downloadUrl)
            guard let packageHTTP = packageResponse as? HTTPURLResponse, (200..<300).contains(packageHTTP.statusCode), packageData.count == entry.size else { throw PatchRemoteSyncError.invalidPatch(entry.fileName) }
            let summary = try PatchPackageCodec.inspect(packageData)
            guard !summary.isPasswordProtected else { continue }
            let decoded = try PatchPackageCodec.decode(packageData, password: nil)
            let existingURL = try PatchProjectLibrary.packageRootURL().appendingPathComponent(entry.fileName)
            let existing = FileManager.default.fileExists(atPath: existingURL.path) ? existingURL : nil
            try PatchProjectLibrary.installImportedPackage(data: packageData, decoded: decoded, summary: summary, existingURL: existing, destinationFilename: entry.fileName)
            managed.insert(entry.fileName)
            categories[entry.fileName] = entry.category
            kinds[entry.fileName] = ["patch", "skin"].contains(entry.kind) ? entry.kind : "patch"
            if let character = entry.character, ["dimitri", "alok"].contains(character) { characters[entry.fileName] = character } else { characters.removeValue(forKey: entry.fileName) }
            if let iconURL = entry.iconUrl, iconURL.scheme?.lowercased() == "https" {
                let (iconData, iconResponse) = try await session.data(from: iconURL)
                if let iconHTTP = iconResponse as? HTTPURLResponse, (200..<300).contains(iconHTTP.statusCode), let iconType = iconHTTP.mimeType, ["image/png", "image/jpeg", "image/webp"].contains(iconType) {
                    let iconName = "\(entry.fileName).\(iconType == "image/png" ? "png" : iconType == "image/webp" ? "webp" : "jpg")"
                    let iconURL = try PatchProjectLibrary.saveRemoteIcon(data: iconData, fileName: iconName)
                    icons[entry.fileName] = iconURL.path
                }
            }
            changed += 1
        }
        let staleRemoteNames = PatchRemoteRemovalPolicy.staleRemoteNames(
            managed: managed,
            categories: categories,
            kinds: kinds,
            characters: characters,
            icons: icons,
            active: active
        )
        let localNamesToRemove = PatchProjectLibrary.localPackageFilenames().subtracting(activeRemoteNames)
        let namesToRemove = staleRemoteNames.union(localNamesToRemove)
        _ = remoteRemovalVerification
        for filename in namesToRemove {
            try? PatchProjectLibrary.removeLocalPackage(named: filename)
            managed.remove(filename)
            categories.removeValue(forKey: filename)
            kinds.removeValue(forKey: filename)
            removedRemoteNames.insert(filename)
            characters.removeValue(forKey: filename)
            if let iconPath = icons.removeValue(forKey: filename) { PatchProjectLibrary.removeRemoteIcon(named: URL(fileURLWithPath: iconPath).lastPathComponent) }
            changed += 1
        }
        UserDefaults.standard.set(Array(managed).sorted(), forKey: managedKey)
        UserDefaults.standard.set(categories, forKey: "3105.managedRemotePatchCategories")
        UserDefaults.standard.set(kinds, forKey: "3105.managedRemotePatchKinds")
        UserDefaults.standard.set(characters, forKey: "3105.managedRemotePatchCharacters")
        UserDefaults.standard.set(icons, forKey: "3105.managedRemotePatchIcons")
        let finalTombstones = PatchRemoteRemovalPolicy.tombstones(existing: removedRemoteNames, stale: namesToRemove, active: activeRemoteNames)
        UserDefaults.standard.set(Array(finalTombstones).sorted(), forKey: "3105.remoteRemovedPatchFilenames")
        return changed
    }
}
