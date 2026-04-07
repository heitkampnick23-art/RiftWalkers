import Foundation
import CoreLocation
import SwiftUI

// MARK: - Mythology System
/// World mythologies that creatures belong to - each with unique visual themes and abilities
enum Mythology: String, Codable, CaseIterable, Identifiable {
    case norse = "Norse"
    case greek = "Greek"
    case egyptian = "Egyptian"
    case japanese = "Japanese"
    case celtic = "Celtic"
    case hindu = "Hindu"
    case aztec = "Aztec"
    case slavic = "Slavic"
    case chinese = "Chinese"
    case african = "African"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .norse: return Color(red: 0.2, green: 0.6, blue: 0.9)
        case .greek: return Color(red: 0.9, green: 0.8, blue: 0.3)
        case .egyptian: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .japanese: return Color(red: 0.9, green: 0.3, blue: 0.4)
        case .celtic: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .hindu: return Color(red: 0.7, green: 0.3, blue: 0.9)
        case .aztec: return Color(red: 0.2, green: 0.7, blue: 0.7)
        case .slavic: return Color(red: 0.5, green: 0.5, blue: 0.8)
        case .chinese: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .african: return Color(red: 0.9, green: 0.5, blue: 0.1)
        }
    }

    var icon: String {
        switch self {
        case .norse: return "bolt.fill"
        case .greek: return "laurel.leading"
        case .egyptian: return "pyramid.fill"
        case .japanese: return "leaf.fill"
        case .celtic: return "tree"
        case .hindu: return "sun.max.fill"
        case .aztec: return "moon.stars.fill"
        case .slavic: return "snowflake"
        case .chinese: return "flame.fill"
        case .african: return "star.fill"
        }
    }

    var lore: String {
        switch self {
        case .norse: return "From the frozen realms of Asgard and Midgard, these creatures harness the fury of storms and frost."
        case .greek: return "Born of Olympus and the ancient seas, these beings command lightning, wisdom, and the tides."
        case .egyptian: return "Risen from the sands of the Nile, guardians of the afterlife wield solar fire and shadow."
        case .japanese: return "Spirits of the yokai realm, shapeshifters that blur the line between nature and the supernatural."
        case .celtic: return "Fae creatures of the mist-shrouded forests, masters of illusion and ancient druidic power."
        case .hindu: return "Divine beings of cosmic energy, wielding the forces of creation and destruction."
        case .aztec: return "Feathered serpents and jaguar warriors from the age of blood and obsidian."
        case .slavic: return "Dark forest dwellers and elemental spirits born from old-world folklore."
        case .chinese: return "Celestial dragons and immortal guardians of the jade emperor's heavenly court."
        case .african: return "Trickster spirits and primordial beasts from the cradle of all mythologies."
        }
    }
}

// MARK: - Element System (Rock-Paper-Scissors with depth)
enum Element: String, Codable, CaseIterable {
    case fire, water, earth, air, lightning, shadow, light, nature, frost, arcane
    case ice, wind
    case `void`

    /// Returns the multiplier when attacking the defender element
    func damageMultiplier(against defender: Element) -> Double {
        let advantages: [Element: Set<Element>] = [
            .fire: [.nature, .frost],
            .water: [.fire, .earth],
            .earth: [.lightning, .fire],
            .air: [.earth, .nature],
            .lightning: [.water, .air],
            .shadow: [.light, .arcane],
            .light: [.shadow, .frost],
            .nature: [.water, .earth],
            .frost: [.air, .nature],
            .arcane: [.fire, .lightning]
        ]
        if advantages[self]?.contains(defender) == true { return 1.5 }
        if advantages[defender]?.contains(self) == true { return 0.67 }
        return 1.0
    }

    var color: Color {
        switch self {
        case .fire: return .red
        case .water: return .blue
        case .earth: return .brown
        case .air, .wind: return .cyan
        case .lightning: return .yellow
        case .shadow: return .purple
        case .light: return .white
        case .nature: return .green
        case .frost, .ice: return Color(red: 0.7, green: 0.9, blue: 1.0)
        case .arcane, .void: return .pink
        }
    }

    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .earth: return "mountain.2.fill"
        case .air, .wind: return "wind"
        case .lightning: return "bolt.fill"
        case .shadow: return "moon.fill"
        case .light: return "sun.max.fill"
        case .nature: return "leaf.fill"
        case .frost, .ice: return "snowflake"
        case .arcane, .void: return "sparkles"
        }
    }
}

// MARK: - Rarity (Gacha-style tiering)
enum Rarity: String, Codable, CaseIterable, Comparable {
    case common, uncommon, rare, epic, legendary, mythic

    var dropWeight: Double {
        switch self {
        case .common: return 0.40
        case .uncommon: return 0.28
        case .rare: return 0.18
        case .epic: return 0.09
        case .legendary: return 0.04
        case .mythic: return 0.01
        }
    }

    var starCount: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 4
        case .legendary: return 5
        case .mythic: return 6
        }
    }

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        case .mythic: return Color(red: 1.0, green: 0.2, blue: 0.4)
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.starCount < rhs.starCount
    }
}

// MARK: - Creature Template (Blueprint from game data)
struct CreatureTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let mythology: Mythology
    let element: Element
    let rarity: Rarity
    let baseHP: Int
    let baseAttack: Int
    let baseDefense: Int
    let baseSpeed: Int
    let description: String
    let abilityIDs: [String]
    let evolutionChainID: String?
    let evolutionLevel: Int?
    let spawnBiomes: [SpawnBiome]
    let spawnTimeWindow: SpawnTimeWindow
    let modelAssetName: String
    let portraitAssetName: String

    var totalBaseStats: Int {
        baseHP + baseAttack + baseDefense + baseSpeed
    }
}

// MARK: - Owned Creature (Player's instance)
struct OwnedCreature: Codable, Identifiable {
    let id: UUID
    let templateID: String
    var nickname: String?
    var level: Int
    var experience: Int
    var currentHP: Int
    var ivHP: Int        // Individual Values (0-31) — unique per catch
    var ivAttack: Int
    var ivDefense: Int
    var ivSpeed: Int
    var equippedAbilityIDs: [String]  // Max 4
    var equippedItemID: String?
    var captureDate: Date
    var captureLocation: CodableCoordinate
    var isFavorite: Bool
    var isInParty: Bool
    var friendship: Int  // 0-255, affects evolution + battle bonuses

    var ivPercentage: Double {
        Double(ivHP + ivAttack + ivDefense + ivSpeed) / 124.0 * 100.0
    }

    func effectiveStat(base: Int, iv: Int) -> Int {
        let levelMultiplier = 1.0 + (Double(level) * 0.05)
        return Int(Double(base + iv) * levelMultiplier)
    }
}

// MARK: - Ability System
struct Ability: Codable, Identifiable {
    let id: UUID
    let name: String
    let element: Element
    let power: Int
    let accuracy: Double      // 0.0 - 1.0
    let cooldown: TimeInterval
    let description: String
    let isUltimate: Bool
    var currentCooldown: TimeInterval

    init(id: UUID = UUID(), name: String, element: Element, power: Int, accuracy: Double, cooldown: TimeInterval, description: String, isUltimate: Bool, currentCooldown: TimeInterval = 0) {
        self.id = id
        self.name = name
        self.element = element
        self.power = power
        self.accuracy = accuracy
        self.cooldown = cooldown
        self.description = description
        self.isUltimate = isUltimate
        self.currentCooldown = currentCooldown
    }
}

// MARK: - Evolution Chain
struct EvolutionChain: Codable, Identifiable {
    let id: String
    let stages: [EvolutionStage]
}

struct EvolutionStage: Codable {
    let templateID: String
    let requiredLevel: Int
    let requiredItems: [String: Int]?   // itemID: quantity
    let requiredFriendship: Int?
    let requiredMythologyAffinity: Int? // How deep into mythology lore tree
}

// MARK: - Spawn Configuration
enum SpawnBiome: String, Codable, CaseIterable {
    case urban, suburban, rural, park, waterfront
    case mountain, forest, desert, historic, commercial
}

enum SpawnTimeWindow: String, Codable {
    case anytime, dayOnly, nightOnly, dawnDusk, midnight
}

// MARK: - Item System
struct GameItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: ItemCategory
    let rarity: Rarity
    let stackable: Bool
    let maxStack: Int
    let effects: [ItemEffect]
    let iconAssetName: String

    enum ItemCategory: String, Codable, CaseIterable {
        case captureSphere   // Like pokeballs
        case potion          // Healing
        case booster         // XP/Stardust boosters
        case evolution       // Evolution materials
        case crafting        // Raw materials
        case equipment       // Held items for creatures
        case cosmetic        // Player skins
        case key             // Rift/dungeon keys
        case lure            // Attract creatures
    }
}

struct ItemEffect: Codable {
    let type: EffectType
    let value: Double

    enum EffectType: String, Codable {
        case captureRateBonus, healHP, healPercent
        case xpMultiplier, dustMultiplier
        case attackBoost, defenseBoost, speedBoost
        case lureRadius, lureDuration
        case riftKeyTier
    }
}

struct InventorySlot: Codable, Identifiable {
    let id: UUID
    let itemID: String
    var quantity: Int
}

// MARK: - Player Model
struct PlayerProfile: Codable {
    var id: String
    var displayName: String
    var avatarAssetName: String
    var level: Int
    var totalXP: Int
    var mythosTokens: Int       // Premium currency
    var stardust: Int           // Free currency (grinding)
    var riftstones: Int         // Earned from territory control
    var faction: Faction?
    var guildID: String?
    var title: String?
    var joinDate: Date
    var totalCreaturesCaught: Int
    var totalBattlesWon: Int
    var totalDistanceWalked: Double  // meters
    var dailyStreak: Int
    var lastDailyClaimDate: Date?
    var battlePassTier: Int
    var battlePassPremium: Bool
    var achievements: [String]       // Achievement IDs
    var equippedCosmetics: [String: String]  // slot: cosmeticID

    var xpForNextLevel: Int {
        // Exponential scaling: each level needs more XP (like Pokemon Go)
        Int(pow(Double(level), 2.5) * 100)
    }

    var levelProgress: Double {
        let currentLevelXP = Int(pow(Double(level - 1), 2.5) * 100)
        let needed = xpForNextLevel - currentLevelXP
        let have = totalXP - currentLevelXP
        return min(1.0, max(0.0, Double(have) / Double(needed)))
    }
}

// MARK: - Faction System (Ingress-style 3 factions)
enum Faction: String, Codable, CaseIterable {
    case asgardians = "Asgardians"    // Order & Protection
    case olympians = "Olympians"       // Power & Glory
    case phantoms = "Phantoms"         // Chaos & Freedom

    var color: Color {
        switch self {
        case .asgardians: return .blue
        case .olympians: return .yellow
        case .phantoms: return .red
        }
    }

    var description: String {
        switch self {
        case .asgardians: return "Guardians of the Bifrost. We protect the rifts and maintain balance between realms."
        case .olympians: return "Champions of Olympus. We seek to harness rift energy and ascend to godhood."
        case .phantoms: return "Children of the Void. We embrace the chaos of the rifts and reshape reality."
        }
    }

    var icon: String {
        switch self {
        case .asgardians: return "shield.fill"
        case .olympians: return "crown.fill"
        case .phantoms: return "eye.fill"
        }
    }
}

// MARK: - Territory System
struct Territory: Codable, Identifiable {
    let id: String
    var name: String
    var centerCoordinate: CodableCoordinate
    var radiusMeters: Double
    var controllingFaction: Faction?
    var controllingGuildID: String?
    var controlStrength: Double  // 0.0 - 1.0
    var defenders: [String]      // OwnedCreature IDs
    var fortificationLevel: Int  // 1-10
    var dailyReward: TerritoryReward
    var lastContestedDate: Date?

    struct TerritoryReward: Codable {
        let riftstones: Int
        let stardust: Int
        let bonusItemIDs: [String]
    }
}

// MARK: - Rift (Dungeon/Raid system)
struct Rift: Codable, Identifiable {
    let id: String
    let name: String
    let mythology: Mythology
    let tier: Int                    // 1-5 difficulty
    let coordinate: CodableCoordinate
    let bossTemplateID: String
    let bossLevel: Int
    let requiredPlayers: Int         // 1 for solo, up to 10 for mega raids
    let rewards: [RiftReward]
    let availableUntil: Date
    let radiusMeters: Double

    var isRaid: Bool { requiredPlayers > 1 }

    struct RiftReward: Codable {
        let itemID: String
        let quantity: Int
        let dropChance: Double
    }
}

// MARK: - Quest System
struct Quest: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: QuestType
    let mythology: Mythology?
    var objectives: [QuestObjective]
    let rewards: QuestRewards
    let expiresAt: Date?
    let isMainStory: Bool
    let chapterIndex: Int?
    let prerequisiteQuestIDs: [String]

    enum QuestType: String, Codable {
        case daily, weekly, story, event, achievement, mythology
    }
}

struct QuestObjective: Codable, Identifiable {
    let id: String
    let description: String
    let type: ObjectiveType
    var currentProgress: Int
    let targetProgress: Int
    let targetDetails: [String: String]  // e.g., "mythology": "norse", "element": "fire"

    var isComplete: Bool { currentProgress >= targetProgress }

    enum ObjectiveType: String, Codable {
        case catchCreature, catchCreatureOfElement, catchCreatureOfMythology
        case winBattle, winPvPBattle, completeRift
        case walkDistance, visitPOI, claimTerritory
        case evolveCreature, craftItem, tradeCreature
        case reachLevel, earnStardust, collectItem
    }
}

struct QuestRewards: Codable {
    let xp: Int
    let stardust: Int
    let mythosTokens: Int
    let items: [String: Int]       // itemID: quantity
    let creatureTemplateID: String? // Guaranteed creature reward
}

// MARK: - Battle Pass (Seasonal monetization — Fortnite model)
struct BattlePass: Codable {
    let seasonID: String
    let seasonName: String
    let mythology: Mythology           // Each season themed around a mythology
    let startDate: Date
    let endDate: Date
    let tiers: [BattlePassTier]
    let maxTier: Int

    struct BattlePassTier: Codable {
        let tier: Int
        let xpRequired: Int
        let freeReward: BattlePassReward?
        let premiumReward: BattlePassReward?
    }

    struct BattlePassReward: Codable {
        let type: RewardType
        let id: String
        let quantity: Int

        enum RewardType: String, Codable {
            case item, creature, cosmetic, currency, title
        }
    }
}

// MARK: - Social Models
struct Guild: Codable, Identifiable {
    let id: String
    var name: String
    var tag: String              // 3-5 char clan tag
    var faction: Faction
    var leaderID: String
    var officerIDs: [String]
    var memberIDs: [String]
    var level: Int
    var totalXP: Int
    var territoriesControlled: Int
    var description: String
    var isRecruiting: Bool
    var maxMembers: Int
    var createdDate: Date

    var memberCount: Int { memberIDs.count }
}

struct TradeOffer: Codable, Identifiable {
    let id: UUID
    let senderID: String
    let receiverID: String
    let offeredCreatureID: UUID
    let requestedCreatureID: UUID?
    let requestedItems: [String: Int]?
    let status: TradeStatus
    let createdDate: Date
    let expiresDate: Date

    enum TradeStatus: String, Codable {
        case pending, accepted, declined, expired, completed
    }
}

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let senderID: String
    let senderDisplayName: String
    let content: String
    let timestamp: Date
    let channelType: ChannelType

    enum ChannelType: String, Codable {
        case global, faction, guild, raid, direct
    }
}

// MARK: - Leaderboard
struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let playerID: String
    let displayName: String
    let avatarAssetName: String
    let faction: Faction?
    let score: Int
    let rank: Int
}

enum LeaderboardType: String, Codable, CaseIterable {
    case totalXP, battleWins, creaturesCaught, distanceWalked
    case raidsDone, territoriesClaimed, pvpRating, seasonBP
}

// MARK: - Map Annotation Models
struct MapCreatureSpawn: Identifiable {
    let id: UUID
    let templateID: String
    let coordinate: CLLocationCoordinate2D
    let spawnedAt: Date
    let expiresAt: Date
    let weatherBoost: Bool

    var isExpired: Bool { Date() > expiresAt }
    var timeRemaining: TimeInterval { expiresAt.timeIntervalSince(Date()) }
}

struct MapPOI: Identifiable {
    let id: String
    let name: String
    let type: POIType
    let coordinate: CLLocationCoordinate2D

    enum POIType: String {
        case riftPortal       // Dungeon entrance
        case ancientShrine    // Pokestop equivalent — spin for items
        case factionTower     // Gym equivalent — territory control
        case tradingPost      // Player trading hub
        case craftingForge    // Crafting station
        case mythologyGate    // Leads to mythology-specific area
    }
}

// MARK: - Weather System (affects spawns + battle)
enum GameWeather: String, Codable, CaseIterable {
    case clear, rain, snow, fog, wind, thunder, heatwave

    var boostedElements: [Element] {
        switch self {
        case .clear: return [.light, .nature]
        case .rain: return [.water, .lightning]
        case .snow: return [.frost, .air]
        case .fog: return [.shadow, .arcane]
        case .wind: return [.air, .earth]
        case .thunder: return [.lightning, .fire]
        case .heatwave: return [.fire, .earth]
        }
    }

    var spawnRateMultiplier: Double { 1.25 }
}

// MARK: - Codable Coordinate Helper
struct CodableCoordinate: Codable {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var coordinate: CLLocationCoordinate2D { clLocation }

    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

// MARK: - Daily Login Reward Calendar
struct DailyReward: Codable, Identifiable {
    let id: Int   // Day number (1-30)
    let items: [String: Int]
    let stardust: Int
    let mythosTokens: Int
    let isMilestone: Bool  // Day 7, 14, 21, 30 get bonus rewards
}

// MARK: - Achievement System
struct Achievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let tiers: [AchievementTier]
    let category: AchievementCategory

    struct AchievementTier: Codable {
        let tier: Int
        let requirement: Int
        let rewardXP: Int
        let rewardTitle: String?
    }

    enum AchievementCategory: String, Codable, CaseIterable {
        case collection, battle, exploration, social, mythology, seasonal
    }
}

// MARK: - Notification Event (for live activities + push)
struct GameEvent: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let mythology: Mythology?
    let startDate: Date
    let endDate: Date
    let bonuses: [EventBonus]
    let featuredCreatureIDs: [String]
    let bannerAssetName: String

    struct EventBonus: Codable {
        let type: BonusType
        let multiplier: Double

        enum BonusType: String, Codable {
            case xp, stardust, catchRate, spawnRate, raidRewards
        }
    }
}
