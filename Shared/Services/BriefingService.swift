import Foundation

public protocol BriefingServing: Sendable {
    func latestBriefing(persona: Persona, scope: BriefingScope) async throws -> Briefing
}

public enum BriefingServiceError: Error, LocalizedError, Sendable {
    case invalidResponse(statusCode: Int, body: String)
    case emptyResult
    case missingConfiguration
    case network(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode, _):
            return "Server returned \(statusCode). Try again in a moment."
        case .emptyResult:
            return "Nothing fresh for this room yet. Check back later."
        case .missingConfiguration:
            return "Briefing service isn't configured."
        case .network:
            return "Couldn't reach today's briefing. Check your connection."
        }
    }
}

public struct SupabaseBriefingService: BriefingServing {
    private let config: AppConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(config: AppConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder.sideline
    }

    public func latestBriefing(persona: Persona, scope: BriefingScope = .national) async throws -> Briefing {
        var components = URLComponents(
            url: config.supabaseURL.appendingPathComponent("rest/v1/briefings"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "persona", value: "eq.\(persona.rawValue)"),
            URLQueryItem(name: "scope", value: "eq.\(scope.rawValue)"),
            URLQueryItem(name: "order", value: "generated_at.desc"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components?.url else {
            throw BriefingServiceError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BriefingServiceError.network(underlying: error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BriefingServiceError.invalidResponse(statusCode: -1, body: String(data: data, encoding: .utf8) ?? "")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw BriefingServiceError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        let rows = try decoder.decode([Briefing].self, from: data)
        guard let briefing = rows.first else {
            throw BriefingServiceError.emptyResult
        }

        return briefing
    }
}

public struct SampleBriefingService: BriefingServing {
    public init() {}

    public func latestBriefing(persona: Persona, scope: BriefingScope = .national) async throws -> Briefing {
        var briefing = Briefing.sample
        if persona != .cocktailParty {
            let tlPrefix = "\(persona.displayName): "
            briefing = Briefing(
                persona: persona,
                scope: scope,
                refreshWindow: .morning,
                headline: Briefing.sample.headline,
                tlDR: "\(tlPrefix)\(Briefing.sample.tlDR)",
                bullets: Briefing.sample.bullets,
                suggestedQuestion: Briefing.sample.suggestedQuestion,
                sourceCount: Briefing.sample.sourceCount,
                generatedAt: Briefing.sample.generatedAt
            )
        }
        return briefing
    }
}

public extension JSONDecoder {
    static var sideline: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    static var sideline: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
