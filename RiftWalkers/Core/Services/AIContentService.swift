import Foundation
import SwiftUI
import CryptoKit

// MARK: - AI Content Service
// Powers AI-generated creature card art (DALL-E 3) and dynamic lore (GPT-4o-mini).
// Researched: Pokemon GO's creature reveal is the #1 dopamine moment.
// AI-generated unique art makes EVERY encounter feel like opening a rare card pack.
// Scopely's MARVEL Strike Force uses unique art per character = emotional attachment = spending.

final class AIContentService: ObservableObject {
    static let shared = AIContentService()

    @Published var isGenerating = false
    @Published var generationQueue: Int = 0

    private let session: URLSession
    private let imageCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default

    // Cloud proxy (key lives server-side, never in the app binary)
    private let proxyBaseURL = "https://riftwalkers-api.heitkampnick23.workers.dev"
    private var localAPIKey: String?  // Optional override for dev/testing
    private let deviceID: String

    // Rate limiting
    private var lastRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 1.0 // 1 request/sec

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
        imageCache.countLimit = 50

        // Stable device ID for rate limiting
        if let stored = UserDefaults.standard.string(forKey: "riftwalkers_device_id") {
            self.deviceID = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "riftwalkers_device_id")
            self.deviceID = newID
        }

        loadLocalAPIKey()
    }

    // MARK: - API Key (optional local override — cloud proxy is the default)

    private func loadLocalAPIKey() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let key = dict["OPENAI_API_KEY"] as? String,
           !key.isEmpty, key != "YOUR_KEY_HERE" {
            self.localAPIKey = key
            return
        }
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            self.localAPIKey = key
        }
    }

    func setAPIKey(_ key: String) {
        self.localAPIKey = key
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }

    /// Always true — cloud proxy provides AI for all users; local key is optional override
    var hasAPIKey: Bool { true }

    /// Whether a local key is configured (for Settings UI status)
    var hasLocalAPIKey: Bool { localAPIKey != nil && !(localAPIKey?.isEmpty ?? true) }

    /// Whether using cloud proxy or local key
    var isUsingCloudProxy: Bool { localAPIKey == nil || localAPIKey?.isEmpty == true }

    // MARK: - Image Cache Directory

    private var cacheDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cache = docs.appendingPathComponent("CreatureCards", isDirectory: true)
        try? fileManager.createDirectory(at: cache, withIntermediateDirectories: true)
        return cache
    }

    private func cacheURL(for creatureID: String, shiny: Bool = false) -> URL {
        let suffix = shiny ? "_shiny" : ""
        return cacheDirectory.appendingPathComponent("\(creatureID)\(suffix).png")
    }

    // MARK: - Generate Creature Card Art (DALL-E 3)

    func generateCreatureCard(
        species: CreatureSpecies,
        isShiny: Bool = false,
        forceRegenerate: Bool = false
    ) async -> UIImage? {
        // Check disk cache first
        let cached = cacheURL(for: species.id, shiny: isShiny)
        if !forceRegenerate, fileManager.fileExists(atPath: cached.path) {
            if let data = try? Data(contentsOf: cached), let img = UIImage(data: data) {
                imageCache.setObject(img, forKey: species.id as NSString)
                return img
            }
        }

        // Check memory cache
        if !forceRegenerate, let img = imageCache.object(forKey: species.id as NSString) {
            return img
        }

        // Rate limit
        await throttle()

        await MainActor.run { isGenerating = true; generationQueue += 1 }
        defer { Task { @MainActor in isGenerating = generationQueue > 1; generationQueue -= 1 } }

        let shinyModifier = isShiny ? "with a radiant golden/holographic shimmer effect, ultra-rare variant, " : ""
        let rarityStyle: String
        switch species.rarity {
        case .common: rarityStyle = "simple, clean design"
        case .uncommon: rarityStyle = "slightly detailed with a subtle glow"
        case .rare: rarityStyle = "detailed with magical aura effects"
        case .epic: rarityStyle = "highly detailed with dramatic lighting and energy effects"
        case .legendary: rarityStyle = "extremely detailed with epic cosmic energy, lightning, and divine aura"
        case .mythic: rarityStyle = "otherworldly detail with reality-warping effects, cosmic fractals, and divine transcendence"
        }

        let prompt = """
        A stunning trading card game illustration of a mythological creature called "\(species.name)" \
        from \(species.mythology.rawValue) mythology. It is a \(species.element.rawValue)-type creature. \
        \(shinyModifier)\(rarityStyle). \
        \(species.lore) \
        Style: Premium digital fantasy card art, vibrant colors, dynamic pose, detailed background \
        matching \(species.mythology.rawValue) mythology themes. Square format, centered creature, \
        no text or borders. Professional TCG quality like Pokemon or Magic: The Gathering card art.
        """

        do {
            let imageData = try await callDALLE(prompt: prompt, size: "1024x1024", quality: species.rarity >= .epic ? "hd" : "standard")

            if let img = UIImage(data: imageData) {
                // Cache to disk
                if let pngData = img.pngData() {
                    try? pngData.write(to: cached)
                }
                // Cache to memory
                imageCache.setObject(img, forKey: species.id as NSString)
                return img
            }
        } catch {
            print("[AI] Image generation failed: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - Generate Creature Lore (GPT-4o-mini)

    func generateLore(for species: CreatureSpecies) async -> String? {
        guard hasAPIKey else { return nil }
        await throttle()

        let prompt = """
        You are a mythology expert and fantasy game writer. Write a 2-3 sentence lore entry for a creature in a mobile game called "RiftWalkers" where mythological creatures appear in the real world through dimensional rifts.

        Creature: \(species.name)
        Mythology: \(species.mythology.rawValue)
        Element: \(species.element.rawValue)
        Rarity: \(species.rarity.rawValue)

        Write dramatic, evocative lore that makes the player feel like this creature is special and worth collecting. Reference authentic \(species.mythology.rawValue) mythology. Keep it under 50 words.
        """

        do {
            let response = try await callGPT(prompt: prompt, maxTokens: 100)
            return response
        } catch {
            print("[AI] Lore generation failed: \(error)")
            return nil
        }
    }

    // MARK: - Generate Dynamic Quest Narrative

    func generateQuestNarrative(title: String, mythology: Mythology?, type: String) async -> String? {
        guard hasAPIKey else { return nil }
        await throttle()

        let mythContext = mythology.map { "Set in \($0.rawValue) mythology. " } ?? ""
        let prompt = """
        Write a brief, immersive quest introduction (2-3 sentences) for a \(type) quest called "\(title)" in a game where mythological rifts open in the real world. \(mythContext)Make it mysterious and exciting. Under 40 words.
        """

        do {
            return try await callGPT(prompt: prompt, maxTokens: 80)
        } catch {
            return nil
        }
    }

    // MARK: - Batch Generate Cards (Background)

    func pregenerateCards(for speciesList: [CreatureSpecies], maxConcurrent: Int = 3) async {
        await withTaskGroup(of: Void.self) { group in
            var running = 0
            for species in speciesList {
                // Skip if already cached
                let cached = cacheURL(for: species.id)
                if fileManager.fileExists(atPath: cached.path) { continue }

                if running >= maxConcurrent {
                    await group.next()
                    running -= 1
                }

                group.addTask {
                    _ = await self.generateCreatureCard(species: species)
                }
                running += 1
            }
        }
    }

    // MARK: - API Calls

    private func callDALLE(prompt: String, size: String, quality: String) async throws -> Data {
        let useLocal = localAPIKey != nil && !(localAPIKey?.isEmpty ?? true)
        let baseURL = useLocal ? "https://api.openai.com" : proxyBaseURL

        var request = URLRequest(url: URL(string: "\(baseURL)/v1/images/generations")!)
        request.httpMethod = "POST"
        if useLocal {
            request.addValue("Bearer \(localAPIKey!)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(deviceID, forHTTPHeaderField: "X-Device-ID")

        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": size,
            "quality": quality,
            "response_format": "b64_json"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        if http.statusCode != 200 {
            if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.httpError(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let b64String = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64String) else {
            throw AIError.invalidResponse
        }

        return imageData
    }

    private func callGPT(prompt: String, maxTokens: Int) async throws -> String {
        let useLocal = localAPIKey != nil && !(localAPIKey?.isEmpty ?? true)
        let baseURL = useLocal ? "https://api.openai.com" : proxyBaseURL

        var request = URLRequest(url: URL(string: "\(baseURL)/v1/chat/completions")!)
        request.httpMethod = "POST"
        if useLocal {
            request.addValue("Bearer \(localAPIKey!)", forHTTPHeaderField: "Authorization")
        }
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(deviceID, forHTTPHeaderField: "X-Device-ID")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a concise fantasy game writer. Respond with ONLY the requested text, no quotes or formatting."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": maxTokens,
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Rate Limiting

    private func throttle() async {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minimumRequestInterval {
            try? await Task.sleep(nanoseconds: UInt64((minimumRequestInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    // MARK: - Errors

    enum AIError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case httpError(Int)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "No OpenAI API key configured"
            case .invalidResponse: return "Invalid response from AI"
            case .httpError(let code): return "HTTP error: \(code)"
            case .apiError(let msg): return "AI error: \(msg)"
            }
        }
    }

    // MARK: - Get Cached Image (Sync)

    func getCachedImage(for speciesID: String, shiny: Bool = false) -> UIImage? {
        // Memory cache
        let key = (shiny ? "\(speciesID)_shiny" : speciesID) as NSString
        if let img = imageCache.object(forKey: key) { return img }

        // Disk cache
        let url = cacheURL(for: speciesID, shiny: shiny)
        if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
            imageCache.setObject(img, forKey: key)
            return img
        }

        return nil
    }
}
