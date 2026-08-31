import Foundation

enum PatchRemoteRemovalPolicy {
    static let verificationMarker = "REAL_REMOTE_REMOVAL_POLICY|NO_BUNDLED_REINSTALL"

    static func staleRemoteNames(
        managed: Set<String>,
        categories: [String: String],
        kinds: [String: String],
        characters: [String: String],
        icons: [String: String],
        active: Set<String>
    ) -> Set<String> {
        let known = managed
            .union(categories.keys)
            .union(kinds.keys)
            .union(characters.keys)
            .union(icons.keys)
        return known.subtracting(active)
    }

    static func tombstones(
        existing: Set<String>,
        stale: Set<String>,
        active: Set<String>
    ) -> Set<String> {
        existing.union(stale).subtracting(active)
    }
}
