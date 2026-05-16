import Foundation

public struct AppConfig: Equatable, Sendable {
    public let supabaseURL: URL
    public let supabaseAnonKey: String

    public init(supabaseURL: URL, supabaseAnonKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> AppConfig? {
        guard
            let rawURL = environment["SIDELINE_SUPABASE_URL"],
            let url = URL(string: rawURL),
            let anonKey = environment["SIDELINE_SUPABASE_ANON_KEY"],
            !anonKey.isEmpty
        else {
            return nil
        }

        return AppConfig(supabaseURL: url, supabaseAnonKey: anonKey)
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> AppConfig? {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SIDELINE_SUPABASE_URL") as? String,
            let url = URL(string: rawURL),
            let anonKey = bundle.object(forInfoDictionaryKey: "SIDELINE_SUPABASE_ANON_KEY") as? String,
            !anonKey.isEmpty,
            !anonKey.hasPrefix("$(")
        else {
            return nil
        }

        return AppConfig(supabaseURL: url, supabaseAnonKey: anonKey)
    }
}
