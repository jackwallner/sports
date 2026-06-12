import Foundation

#if canImport(SwiftData)
import SwiftData

@available(iOS 17.0, macOS 14.0, *)
@Model
public final class CachedBriefingRecord {
    @Attribute(.unique) public var cacheKey: String
    public var payload: Data
    public var generatedAt: Date
    public var cachedAt: Date

    public init(cacheKey: String, payload: Data, generatedAt: Date, cachedAt: Date = Date()) {
        self.cacheKey = cacheKey
        self.payload = payload
        self.generatedAt = generatedAt
        self.cachedAt = cachedAt
    }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class BriefingCache {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public convenience init() throws {
        let schema = Schema([CachedBriefingRecord.self])
        let configuration = ModelConfiguration(schema: schema)
        try self.init(container: ModelContainer(for: schema, configurations: configuration))
    }

    public func save(_ briefing: Briefing) throws {
        let context = ModelContext(container)
        let key = Self.cacheKey(persona: briefing.persona, scope: briefing.scope)
        let payload = try JSONEncoder.sideline.encode(briefing)

        let descriptor = FetchDescriptor<CachedBriefingRecord>(
            predicate: #Predicate { $0.cacheKey == key }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.payload = payload
            existing.generatedAt = briefing.generatedAt
            existing.cachedAt = Date()
        } else {
            context.insert(
                CachedBriefingRecord(
                    cacheKey: key,
                    payload: payload,
                    generatedAt: briefing.generatedAt
                )
            )
        }

        try context.save()
    }

    public func load(persona: Persona, scope: BriefingScope) throws -> Briefing? {
        let context = ModelContext(container)
        let key = Self.cacheKey(persona: persona, scope: scope)
        let descriptor = FetchDescriptor<CachedBriefingRecord>(
            predicate: #Predicate { $0.cacheKey == key }
        )

        guard let record = try context.fetch(descriptor).first else {
            return nil
        }

        return try JSONDecoder.sideline.decode(Briefing.self, from: record.payload)
    }

    public static func cacheKey(persona: Persona, scope: BriefingScope) -> String {
        "\(persona.rawValue):\(scope.rawValue)"
    }
}
#endif
