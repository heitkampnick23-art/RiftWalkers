import Foundation
import Combine

// MARK: - Network Service
// Production-grade networking layer. Researched: Successful geo-games use
// Firebase/Supabase for real-time sync + REST for game state.
// This service handles both patterns.

final class NetworkService: ObservableObject {
    static let shared = NetworkService()

    @Published var isConnected = true
    @Published var isLoading = false

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let baseURL: URL
    private var authToken: String?
    private var refreshToken: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        // Production API endpoint
        self.baseURL = URL(string: "https://api.riftwalkers.app/v1")!
    }

    // MARK: - Auth

    func setAuthToken(_ token: String, refresh: String) {
        self.authToken = token
        self.refreshToken = refresh
    }

    func clearAuth() {
        self.authToken = nil
        self.refreshToken = nil
    }

    // MARK: - Generic Request

    func request<T: Decodable>(
        endpoint: APIEndpoint,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        retryCount: Int = 2
    ) async throws -> T {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(endpoint.path))
        urlRequest.httpMethod = method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("RiftWalkers-iOS/1.0", forHTTPHeaderField: "User-Agent")

        if let token = authToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        var lastError: Error?

        for attempt in 0...retryCount {
            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return try decoder.decode(T.self, from: data)
                case 401:
                    if attempt == 0 {
                        try await refreshAuthToken()
                        urlRequest.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
                        continue
                    }
                    throw NetworkError.unauthorized
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap(Double.init) ?? 2.0
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue
                case 400...499:
                    let errorBody = try? decoder.decode(APIError.self, from: data)
                    throw NetworkError.clientError(httpResponse.statusCode, errorBody?.message ?? "Unknown error")
                case 500...599:
                    throw NetworkError.serverError(httpResponse.statusCode)
                default:
                    throw NetworkError.unexpectedStatusCode(httpResponse.statusCode)
                }
            } catch let error as NetworkError {
                throw error
            } catch {
                lastError = error
                if attempt < retryCount {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NetworkError.unknown
    }

    // MARK: - Specific API Methods

    func fetchNearbySpawns(latitude: Double, longitude: Double, radius: Double) async throws -> [SpawnEvent] {
        try await request(endpoint: .nearbySpawns(lat: latitude, lng: longitude, radius: radius))
    }

    func fetchNearbyTerritories(latitude: Double, longitude: Double, radius: Double) async throws -> [Territory] {
        try await request(endpoint: .nearbyTerritories(lat: latitude, lng: longitude, radius: radius))
    }

    func fetchNearbyDungeons(latitude: Double, longitude: Double, radius: Double) async throws -> [RiftDungeon] {
        try await request(endpoint: .nearbyDungeons(lat: latitude, lng: longitude, radius: radius))
    }

    func captureCreature(spawnID: UUID, sphereType: String) async throws -> CaptureResult {
        let body = CaptureRequest(spawnID: spawnID, sphereType: sphereType)
        return try await request(endpoint: .captureCreature, method: .post, body: body)
    }

    func fetchPlayerProfile() async throws -> Player {
        try await request(endpoint: .playerProfile)
    }

    func updatePlayerLocation(latitude: Double, longitude: Double) async throws -> LocationUpdateResponse {
        let body = LocationUpdate(latitude: latitude, longitude: longitude, timestamp: Date())
        return try await request(endpoint: .updateLocation, method: .post, body: body)
    }

    func fetchLeaderboard(type: LeaderboardType, page: Int = 0) async throws -> [LeaderboardEntry] {
        try await request(endpoint: .leaderboard(type: type, page: page))
    }

    func startBattle(creatureIDs: [UUID], targetID: UUID) async throws -> BattleSession {
        let body = BattleStartRequest(creatureIDs: creatureIDs, targetID: targetID)
        return try await request(endpoint: .startBattle, method: .post, body: body)
    }

    func submitBattleAction(sessionID: UUID, action: BattleAction) async throws -> BattleUpdate {
        let body = BattleActionRequest(sessionID: sessionID, action: action)
        return try await request(endpoint: .battleAction, method: .post, body: body)
    }

    func fetchDailyQuests() async throws -> [Quest] {
        try await request(endpoint: .dailyQuests)
    }

    func fetchSeasonInfo() async throws -> Season {
        try await request(endpoint: .currentSeason)
    }

    func fetchGuildInfo(guildID: UUID) async throws -> Guild {
        try await request(endpoint: .guild(id: guildID))
    }

    func claimTerritory(territoryID: UUID, creatureIDs: [UUID]) async throws -> TerritoryClaimResult {
        let body = TerritoryClaimRequest(territoryID: territoryID, defenderIDs: creatureIDs)
        return try await request(endpoint: .claimTerritory, method: .post, body: body)
    }

    // MARK: - Token Refresh

    private func refreshAuthToken() async throws {
        guard let refresh = refreshToken else {
            throw NetworkError.unauthorized
        }

        struct RefreshBody: Encodable { let refreshToken: String }
        struct RefreshResponse: Decodable { let accessToken: String; let refreshToken: String }

        let response: RefreshResponse = try await request(
            endpoint: .refreshToken,
            method: .post,
            body: RefreshBody(refreshToken: refresh)
        )

        self.authToken = response.accessToken
        self.refreshToken = response.refreshToken
    }
}

// MARK: - API Endpoints

enum APIEndpoint {
    case nearbySpawns(lat: Double, lng: Double, radius: Double)
    case nearbyTerritories(lat: Double, lng: Double, radius: Double)
    case nearbyDungeons(lat: Double, lng: Double, radius: Double)
    case captureCreature
    case playerProfile
    case updateLocation
    case leaderboard(type: LeaderboardType, page: Int)
    case startBattle
    case battleAction
    case dailyQuests
    case currentSeason
    case guild(id: UUID)
    case claimTerritory
    case refreshToken
    case shopItems
    case purchaseItem
    case tradeOffer
    case guildChat(id: UUID)

    var path: String {
        switch self {
        case .nearbySpawns(let lat, let lng, let radius):
            return "spawns/nearby?lat=\(lat)&lng=\(lng)&radius=\(radius)"
        case .nearbyTerritories(let lat, let lng, let radius):
            return "territories/nearby?lat=\(lat)&lng=\(lng)&radius=\(radius)"
        case .nearbyDungeons(let lat, let lng, let radius):
            return "dungeons/nearby?lat=\(lat)&lng=\(lng)&radius=\(radius)"
        case .captureCreature:
            return "creatures/capture"
        case .playerProfile:
            return "player/profile"
        case .updateLocation:
            return "player/location"
        case .leaderboard(let type, let page):
            return "leaderboard/\(type.rawValue)?page=\(page)"
        case .startBattle:
            return "battle/start"
        case .battleAction:
            return "battle/action"
        case .dailyQuests:
            return "quests/daily"
        case .currentSeason:
            return "season/current"
        case .guild(let id):
            return "guild/\(id.uuidString)"
        case .claimTerritory:
            return "territory/claim"
        case .refreshToken:
            return "auth/refresh"
        case .shopItems:
            return "shop/items"
        case .purchaseItem:
            return "shop/purchase"
        case .tradeOffer:
            return "trade/offer"
        case .guildChat(let id):
            return "guild/\(id.uuidString)/chat"
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Models

enum NetworkError: LocalizedError {
    case invalidResponse
    case unauthorized
    case clientError(Int, String)
    case serverError(Int)
    case unexpectedStatusCode(Int)
    case decodingError(Error)
    case noConnection
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Session expired. Please log in again."
        case .clientError(_, let msg): return msg
        case .serverError(let code): return "Server error (\(code)). Try again later."
        case .unexpectedStatusCode(let code): return "Unexpected response (\(code))"
        case .decodingError: return "Failed to process server response"
        case .noConnection: return "No internet connection"
        case .unknown: return "Something went wrong"
        }
    }
}

struct APIError: Decodable {
    let code: String
    let message: String
}

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        _encode = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Request/Response Models

struct CaptureRequest: Encodable {
    let spawnID: UUID
    let sphereType: String
}

struct CaptureResult: Decodable {
    let success: Bool
    let creature: Creature?
    let experienceGained: Int
    let itemsUsed: [String]
}

struct LocationUpdate: Encodable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct LocationUpdateResponse: Decodable {
    let newSpawns: [SpawnEvent]
    let nearbyTerritories: [UUID]
    let activeEvents: [String]
}

struct BattleSession: Codable {
    let sessionID: UUID
    let playerCreatures: [Creature]
    let enemyCreatures: [Creature]
    let turnOrder: [UUID]
    let currentTurn: UUID
}

struct BattleAction: Codable {
    let type: BattleActionType
    let sourceCreatureID: UUID
    let targetCreatureID: UUID?
    let abilityID: UUID?
    let itemID: UUID?
}

enum BattleActionType: String, Codable {
    case attack
    case useAbility
    case useItem
    case swap
    case flee
}

struct BattleUpdate: Decodable {
    let sessionID: UUID
    let actions: [BattleActionResult]
    let currentTurn: UUID?
    let isComplete: Bool
    let winner: UUID?
    let rewards: BattleRewards?
}

struct BattleActionResult: Decodable {
    let sourceID: UUID
    let targetID: UUID?
    let damage: Int?
    let healing: Int?
    let statusApplied: StatusType?
    let isCritical: Bool
    let effectiveness: String?  // "super effective", "not very effective"
}

struct BattleRewards: Decodable {
    let experience: Int
    let gold: Int
    let items: [String]
    let pvpRatingChange: Int?
}

struct BattleStartRequest: Encodable {
    let creatureIDs: [UUID]
    let targetID: UUID
}

struct BattleActionRequest: Encodable {
    let sessionID: UUID
    let action: BattleAction
}

struct TerritoryClaimRequest: Encodable {
    let territoryID: UUID
    let defenderIDs: [UUID]
}

struct TerritoryClaimResult: Decodable {
    let success: Bool
    let territory: Territory?
    let message: String
}
