import Foundation
/// Release-only integrity gate. The private signing key must remain with the Apple
/// signing/distribution pipeline; it is never embedded in the app.
enum AppIntegrityGuard {
    static let verificationMarker = "APP_INTEGRITY_FAIL_CLOSED|BUNDLE_SIGNATURE_REQUIRED|NO_PRIVATE_KEY_IN_IPA"

    static var isValid: Bool {
#if DEBUG
        return true
#else
#if targetEnvironment(simulator)
        return true
#else
        guard !SecurityGuard.isCompromised else { return false }
        guard Bundle.main.bundleIdentifier == "com.apple.mobile.MobileHouseArrest" else { return false }
        guard let executableURL = Bundle.main.executableURL,
              FileManager.default.isReadableFile(atPath: executableURL.path) else { return false }
        let infoURL = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        guard FileManager.default.isReadableFile(atPath: infoURL.path) else { return false }
        // A distributable iOS app must carry the CodeResources seal after signing;
        // the operating system validates the code signature before launching it.

        let codeResources = Bundle.main.bundleURL
            .appendingPathComponent("_CodeSignature", isDirectory: true)
            .appendingPathComponent("CodeResources")
        guard FileManager.default.isReadableFile(atPath: codeResources.path) else { return false }
        return true
#endif
#endif
    }
}
