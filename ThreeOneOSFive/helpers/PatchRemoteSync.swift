import Foundation

struct RemotePatchManifest: Decodable {
    struct Entry: Decodable {
        let id: Int
        let name: String
        let description: String
        let version: String
        let category: String
        let fileName: String
        let size: Int
        let downloadUrl: URL
    }
    let schemaVersion: Int
    let revision: String
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
    static let manifestURL = URL(string: "https://patch3105-zrifekat.manus.space/api/v1/manifest.json")!
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
        var managed = Set(UserDefaults.standard.stringArray(forKey: managedKey) ?? [])
        var active = Set<String>()
        var categories = UserDefaults.standard.dictionary(forKey: "3105.managedRemotePatchCategories") as? [String: String] ?? [:]
        var changed = 0
        for entry in manifest.patches {
            guard ["normal", "max"].contains(entry.category), entry.downloadUrl.scheme?.lowercased() == "https", entry.downloadUrl.user == nil, entry.downloadUrl.password == nil, entry.fileName.lowercased().hasSuffix(".3105") else { throw PatchRemoteSyncError.invalidPatch(entry.fileName) }
            active.insert(entry.fileName)
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
            changed += 1
        }
        for filename in managed.subtracting(active) {
            try? PatchProjectLibrary.removeManagedPackage(named: filename)
            managed.remove(filename)
            categories.removeValue(forKey: filename)
            changed += 1
        }
        UserDefaults.standard.set(Array(managed).sorted(), forKey: managedKey)
        UserDefaults.standard.set(categories, forKey: "3105.managedRemotePatchCategories")
        return changed
    }
}
