import Foundation



struct PatchLibraryItem: Identifiable {
    
    let summary: PatchPackageSummary
    
    var project: PatchProject?
    
    var contentKey: Data?
    
    var packageURL: URL
    

    
    var id: UUID { summary.packageID }
    
    var isLocked: Bool { project == nil }
    
    var workspaceURL: URL? {
        
        PatchWorkspaceService.workspaceURL(projectID: id)
        
    }
    
}



struct PatchPasswordRequest: Identifiable {
    
    let summary: PatchPackageSummary
    
    var id: UUID { summary.packageID }
    
}



enum PatchProjectLibrary {
    
    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        
        let base = try fileManager.url(
            
            for: .applicationSupportDirectory,
            
            in: .userDomainMask,
            
            appropriateFor: nil,
            
            create: true
            
        )
        
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        
        return root
        
    }
    

    
    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        
        let root = try packageRootURL(fileManager: fileManager)
        
            .appendingPathComponent("Backups", isDirectory: true)
        
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        
        return root
        
    }
    

    
    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        
        installBundledPackagesIfNeeded(fileManager: fileManager)
        
        guard let root = try? packageRootURL(fileManager: fileManager),
        
              let urls = try? fileManager.contentsOfDirectory(
                  
                at: root,
                  
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                  
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
                  
              ) else { return [] }
        

        
        var byID: [UUID: PatchLibraryItem] = [:]
        
        for url in urls where url.pathExtension.lowercased() == "3105" {
            
            do {
                
                let data = try readPackage(at: url)
                
                let summary = try PatchPackageCodec.inspect(data)
                
                let decoded: DecodedPatchPackage?
                
                if let contentKey = try PatchKeyStore.load(for: summary) {
                    
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                    
                } else if summary.isPasswordProtected {
                    
                    decoded = nil
                    
                } else {
                    
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                    
                }
                
                let item = PatchLibraryItem(
                    
                    summary: summary,
                    
                    project: decoded?.project,
                    
                    contentKey: decoded?.contentKey,
                    
                    packageURL: url
                    
                )
                
                if summary.schemaVersion >= 2, let project = decoded?.project {
                    
                    do {
                        
                        _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                        
                    } catch {
                        
                        log("patch: workspace unavailable for \(project.id.uuidString)")
                        
                    }
                    
                }
                
                byID[summary.packageID] = item
                
            } catch {
                
                log("patch: skipped invalid local package \(url.lastPathComponent)")
                
            }
            
        }
        
        return byID.values.sorted {
            
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
            
        }
        
    }
    

    
    private static func installBundledPackagesIfNeeded(fileManager: FileManager) {
        
        guard let root = try? packageRootURL(fileManager: fileManager) else { return }
        
        let bundledURLs = Bundle.main.urls(forResourcesWithExtension: "3105", subdirectory: "Patches") ?? []
        
        for sourceURL in bundledURLs {
            
            let destination = root.appendingPathComponent(sourceURL.lastPathComponent)
            
            guard !fileManager.fileExists(atPath: destination.path) else { continue }
            
            do {
                
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                
                let summary = try PatchPackageCodec.inspect(data)
                
                guard !summary.isPasswordProtected else { continue }
                
                let decoded = try PatchPackageCodec.decode(data, password: nil)
                
                try installImportedPackage(
                    
                    data: data,
                    
                    decoded: decoded,
                    
                    summary: summary,
                    
                    existingURL: nil,
                    
                    fileManager: fileManager
                    
                )
                
            } catch {
                
                log("patch: skipped bundled package \(sourceURL.lastPathComponent)")
                
            }
            
        }
        
    }
    

    
    static func readPackage(at url: URL) throws -> Data {
        
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        
        guard values.isDirectory != true,
        
              values.isSymbolicLink != true,
        
              values.isRegularFile == true else {
                  
            throw PatchPackageError.invalidProject
                  
              }
        
        return try Data(contentsOf: url, options: .mappedIfSafe)
        
    }
    

    
    static func save(
        
        data: Data,
        
        projectName: String,
        
        existingURL: URL? = nil,
        
        fileManager: FileManager = .default
        
    ) throws -> URL {
        
        let destination: URL
        
        if let existingURL {
            
            destination = existingURL
            
        } else {
            
            let root = try packageRootURL(fileManager: fileManager)
            
            let baseName = sanitizedFilename(projectName)
            
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("3105")
            
            var suffix = 2
            
            while fileManager.fileExists(atPath: candidate.path) {
                
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("3105")
                
                suffix += 1
                
            }
            
            destination = candidate
            
        }
        
        try data.write(to: destination, options: [.atomic, .completeFileProt




































































































































