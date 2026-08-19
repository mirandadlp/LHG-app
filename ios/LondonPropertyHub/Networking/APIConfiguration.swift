import Foundation

/// Where the app talks to.
///
/// The base URL is read from `API_BASE_URL` in Info.plist, which is driven by
/// the build configuration — Debug points at your machine, Release at
/// production. Change it in Config/Debug.xcconfig and Config/Release.xcconfig,
/// never in code.
enum APIConfiguration {

    static var baseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: raw.trimmingCharacters(in: .whitespaces)),
            url.scheme != nil
        else {
            assertionFailure("API_BASE_URL is missing or malformed in Info.plist")
            return URL(string: "http://localhost:8000")!
        }

        return url
    }

    static var apiURL: URL { baseURL.appendingPathComponent("api") }

    /// Shown on the sign-in screen so a tester can confirm which environment a
    /// build points at without digging through settings.
    static var environmentLabel: String {
        Bundle.main.object(forInfoDictionaryKey: "API_ENVIRONMENT_LABEL") as? String ?? ""
    }

    static var isProduction: Bool { environmentLabel.lowercased() == "production" }

    /// Sent as the token name so a user can tell their devices apart in their
    /// account's device list.
    ///
    /// `UIDevice.current.name` would be the obvious source, but it is
    /// main-actor isolated — unreachable from here — and has been redacted to a
    /// generic string since iOS 16 anyway. The hardware identifier from `uname`
    /// is nonisolated and more specific.
    static var deviceName: String {
        var info = utsname()
        uname(&info)

        let identifier = withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }

        #if targetEnvironment(simulator)
        return "Simulator (\(identifier))"
        #else
        return identifier.isEmpty ? "iOS device" : identifier
        #endif
    }
}
