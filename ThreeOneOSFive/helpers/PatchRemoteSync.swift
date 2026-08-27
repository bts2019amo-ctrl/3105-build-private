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
    
    let themeColor: String?
    
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
    
    static let manifestURL = URL(string: "https://proxypatch-5pmh6tcn.manus.space/manifest.json")!
    
    static let maxPatchBytes = 25 * 1024 * 1024
    
    static let cachedManifestName = "remote-manifest.json"
    

    
    static func synchronize(fileManager: FileManager = .default) async throws -> Int {
        
        let root = try PatchProjectLibrary.packageRootURL(fileManager: fileManager)
        
        let cachedURL = root.appendingPathComponent(cachedManifestName)
        
        let oldManifest: RemotePatchManifest? = try? loadManifest(at: cachedURL, fileManager: fileManager)
        

        
        let configuration = URLSessionConfiguration.default
        
        configuration.timeoutIntervalForRequest = 30
        
        configuration.timeoutIntervalForResource = 180
        
        let session = URLSession(configuration: configuration)
        
        defer { session.invalidateAndCancel() }
        

        
        let manifestData: Data
        
        do {
            
            var request = URLRequest(url: manifestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            
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
        
        if let themeColor = manifest.themeColor, isValidThemeColor(themeColor) {
            
            UserDefaults.standard.set(themeColor.uppercased(), forKey: AppTheme.themeColorKey)
            
        }
        
        NotificationCenter.default.post(name: .proxySystemRemoteConfigurationDidChange, object: nil)
        

        
        var remoteNames = UserDefaults.standard.dictionary(forKey: "proxy_system_remote_patch_names") as? [String: String] ?? [:]
        
        let oldNames = Set(oldManifest?.patches.map { $0.filename } ?? [])
        
        let newNames = Set(manifest.patches.map { $0.filename })
        
        var changed = 0
        

        
        for entry in manifest.patches {
            
            guard entry.filename.lowercased().hasSuffix(".3105") else { throw PatchRemoteSyncError.invalidPatchName }
            
            guard entry.sizeBytes > 0, entry.sizeBytes <= maxPatchBytes else { throw PatchRemoteSyncError.invalidSize }
            
            remoteNames[entry.sha256] = entry.filename
            

            
            let localURL = root.appendingPathComponent(entry.filename)
            
            let previousURL = oldManifest?.patches.first(where: { $0.sha256 == entry.sha256 })
            
                .map { root.appendingPathComponent($0.filename) }
            
                .flatMap { fileManager.fileExists(atPath: $0.path) ? $0 : nil }
            
            let existingURL = previousURL ?? (fileManager.fileExists(atPath: localURL.path) ? localURL : nil)
            

            
            if let existingURL,
            
               let localData = try? PatchProjectLibrary.readPackage(at: existingURL),
            
               sha256(localData) == entry.sha256 {
                   
                if existingURL.path != localURL.path {
                    
                    try? fileManager.removeItem(at: localURL)
                    
                    try fileManager.moveItem(at: existingURL, to: localURL)
                    
                }
                   
                continue
                   
               }
            

            
            guard let remoteURL = URL(string: entry.url, relativeTo: manifestURL)?.absoluteURL else {
                
                throw PatchRemoteSyncError.invalidManifest
                
            }
            
            var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 180)
            
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
                    
                    existingURL: existingURL,
                    
                    preferredFilename: entry.filename,
                    
                    fileManager: fileManager
                    
                )
                
            } catch PatchPackageError.invalidProject {
                
                throw PatchRemoteSyncError.passwordProtectedRemotePatch
                
            }
            
            changed += 1
            
        }
        

        
        for removedName in oldNames.subtracting(newNames) {
            
            try? fileManager.removeItem(at: root.appendingPathComponent(removedName))
            
        }
        

        
        UserDefaults.standard.set(remoteNames, forKey: "proxy_system_remote_patch_names")
        
        try manifestData.write(to: cachedURL, options: [.atomic])
        
        return changed
        
    }
    

    
    private static func isValidThemeColor(_ value: String) -> Bool {
        
        value.range(of: #"^#[0-9A-Fa-f]{6}$"#, options:











































































































































