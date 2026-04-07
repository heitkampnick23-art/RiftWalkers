import Foundation
import CoreLocation
import SwiftUI

/// MARK: - Type Aliases
typealias Season = BattlePass
typealias ObjectiveType = QuestObjective.ObjectiveType

/// MARK: - Player (full player model used by ProgressionManager & views)
struct Player: Codable {
    var id: UUID
    var username: String
    var displayName: String
    var avatarURL: String?
    var level: Int
    var experience: Int
    var title: String?
    var gold: Int
    var riftGems: Int
    var essences: [Mythology: Int]
    var riftDust: Int
    var creatures: [UUID]
    var activeParty: [UUID]
    var creaturesSeen: Int
    var creaturesCaught: Int
    var items: [InventoryItem]
    var maxInventorySlots: Int
    var guildID: UUID?
    var friendIDs: [UUID]
    var pvpRating: Int
    var pvpWins: Int
    var pvpLosses: Int
    var questsCompleted: Int
    var riftsCleared: Int
    var territoriesClaimed: Int
    var totalDistanceWalked: Double
    var dailyStreak: Int
    var lastLoginDate: Date?
    var achievements: [PlayerAchievement]
    var battlePassTier: Int
    var battlePassPremium: Bool
    var joinDate: Date
    var totalPlayTime: TimeInterval
    var faction: Faction?

    var experienceToNextLevel: Int {
        Int(pow(Double(level), 2.5) * 100)
    }

    var levelProgress: Double {
        Double(experience) / Double(max(1, experienceToNextLevel))
    }
}

/// MARK: - PlayerAchievement (runtime achievement instances)
struct PlayerAchievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let tier: AchievementTier
    var isUnlocked: Bool
    var unlockedDate: Date?
    var rewardTitle: String?
}

/// MARK: - BiomeType
enum BiomeType: String, Codable, CaseIterable {
    case urban, suburban, park, water, historic, rural, forest, mountain, desert, commercial
    case cemetery, university, coastal, volcanic, cave, ruins, temple, swamp, tundra, grassland, residential
}

/// MARK: - TimeOfDay
enum TimeOfDay: String, Codable, CaseIterable {
    case dawn, day, dusk, night, anytime, any
}

/// MARK: - WeatherCondition
enum WeatherCondition: String, Codable, CaseIterable {
    case clear, rainy, snowy, cloudy, sunny, foggy, windy, stormy
    case fog, snow, storm, rain, wind, heatwave, sandstorm, extreme
}

/// MARK: - GeoPoint
struct GeoPoint: Codable, Equatable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// MARK: - StatusType & StatusEffect
enum StatusType: String, Codable, CaseIterable {
    case burn, freeze, poison, stun, sleep, confuse, blind, curse, bless, rage
}

struct StatusEffect: Identifiable, Codable {
    let id: UUID
    let type: StatusType
    var turnsRemaining: Int

    init(type: StatusType, turnsRemaining: Int) {
        self.id = UUID()
        self.type = type
        self.turnsRemaining = turnsRemaining
    }
}

/// MARK: - EvolutionCost
struct EvolutionCost: Codable {
    let essenceCost: Int
    let goldCost: Int
    let requiredLevel: Int
    let requiredItem: String?
}

/// MARK: - CreatureSpecies
struct CreatureSpecies: Identifiable, Codable {
    let id: String
    let name: String
    let mythology: Mythology
    let element: Element
    let rarity: Rarity
    let lore: String
    let baseHP: Int
    let baseAttack: Int
    let baseDefense: Int
    let baseSpeed: Int
    let baseSpecial: Int
    let abilities: [String]
    let passiveAbility: String?
    let evolutionChainID: String?
    let evolutionStage: Int
    let evolvesInto: String?
    let shinyRate: Double
    let biomePreference: [BiomeType]
    let timePreference: TimeOfDay
    let weatherPreference: [WeatherCondition]
    let modelAsset: String
    let iconAsset: String

    // Computed properties for backward compatibility
    var spawnWeight: Double { rarity.dropWeight }
    var icon: String { iconAsset }
    var biomes: [BiomeType] { biomePreference }
    var description: String { lore }

    // Rarity extension for species
    var stars: Int { rarity.starCount }
}

/// MARK: - SpawnEvent
struct SpawnEvent: Identifiable, Codable {
    let id: UUID
    let speciesID: String
    let location: GeoPoint
    let spawnedAt: Date
    let expiresAt: Date
    var isShiny: Bool
    let isEvent: Bool
    var weatherBoosted: Bool
    var isCaptures: Bool

    var isExpired: Bool { Date() > expiresAt }
    var timeRemaining: TimeInterval { expiresAt.timeIntervalSince(Date()) }
}

/// MARK: - Creature (Player's actual creature instance)
struct Creature: Identifiable, Codable {
    let id: UUID
    var speciesID: String
    var name: String
    var nickname: String?
    let mythology: Mythology
    let element: Element
    let rarity: Rarity
    var level: Int
    var experience: Int
    var baseHP: Int
    var baseAttack: Int
    var baseDefense: Int
    var baseSpeed: Int
    var baseSpecial: Int
    let ivHP: Int
    let ivAttack: Int
    let ivDefense: Int
    let ivSpeed: Int
    let ivSpecial: Int
    var abilities: [Ability]
    var passiveAbility: Ability?
    var currentHP: Int
    var statusEffects: [StatusEffect]
    let isShiny: Bool
    let captureDate: Date
    let captureLocation: GeoPoint
    var evolutionStage: Int
    let evolutionChainID: String?
    var canEvolve: Bool
    var evolutionCost: EvolutionCost?
    var affection: Int
    var lastFedDate: Date?
    var lastPlayedDate: Date?

    var displayName: String { nickname ?? name }
    var maxHP: Int { baseHP + ivHP + level * 3 }
    var attack: Int { baseAttack + ivAttack + level * 2 }
    var defense: Int { baseDefense + ivDefense + level * 2 }
    var speed: Int { baseSpeed + ivSpeed + level * 2 }
    var special: Int { baseSpecial + ivSpecial + level * 2 }
    var combatPower: Int {
        let stats = attack + defense + speed + special
        return stats / 4 * (level / 10 + 1)
    }
}

/// MARK: - RiftDungeon
struct RiftDungeon: Identifiable, Codable {
    let id: UUID
    let name: String
    let location: GeoPoint
    let tier: Int
    let mythology: Mythology
    let difficulty: Int
    let rewards: [String]
    let isBossRush: Bool
    let requiredLevel: Int
    let expiresAt: Date?
}

/// MARK: - ItemType (standalone enum used by InventoryView)
enum ItemType: String, Codable, CaseIterable {
    case captureSphere, potion, revive, booster, lure, incense
    case evolutionStone, craftingMaterial, equipment, key, food, cosmetic
}

/// MARK: - InventoryItem
struct InventoryItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let type: ItemType
    let rarity: Rarity
    let iconAsset: String
    var quantity: Int
    var effects: [ItemEffect]
}

/// MARK: - TerritoryType
enum TerritoryType: String, Codable, CaseIterable {
    case riftNode, sanctuary, forge, arena, library, market, watchtower
}

/// MARK: - TerritoryResources
struct TerritoryResources: Codable {
    let goldPerHour: Int
    let essencePerHour: Int
    let essenceType: Mythology
    let riftDustPerHour: Int
}

/// MARK: - AchievementTier (used by ProfileView)
enum AchievementTier: String, Codable, CaseIterable {
    case bronze, silver, gold, platinum, diamond
}

/// MARK: - StructureType (used by TerritoryDetailView)
enum StructureType: String, Codable, CaseIterable {
    case wall, tower, gate, barracks, shrine, forge, vault
    case turret, healingWell, essenceExtractor, wardStone, portalGate
}

/// MARK: - Quest Extensions (add missing computed properties)
extension Quest {
    var isActive: Bool {
        if let expires = expiresAt {
            return Date() < expires
        }
        return true
    }

    var isCompleted: Bool {
        objectives.allSatisfy { $0.isComplete }
    }

    var narrativeText: String? {
        isMainStory ? description : nil
    }
}

/// MARK: - Additional QuestType cases
extension Quest.QuestType {
    static var territory: Quest.QuestType { .daily }
    static var social: Quest.QuestType { .weekly }
    static var battlePass: Quest.QuestType { .event }
}

/// MARK: - Guild.territoriesOwned alias
extension Guild {
    var territoriesOwned: Int { territoriesControlled }
}

/// MARK: - Rarity extensions
extension Rarity {
    var stars: Int { starCount }
    var spawnWeight: Double { dropWeight }
}

/// MARK: - Ability passive effect helper
extension Ability {
    enum PassiveEffect: String {
        case critRateUp, experienceBoost, healOnKill, nightProwler
        case weatherBoost, elementalResist, territoryGuard
    }
    var effect: PassiveEffect? {
        // Passive abilities map name to effect
        switch name.lowercased() {
        case let n where n.contains("crit"): return .critRateUp
        default: return nil
        }
    }
}

/// MARK: - ItemEffect.EffectType extension
extension ItemEffect.EffectType {
    static let heal = ItemEffect.EffectType.healHP
}

/// MARK: - Territory bridging
extension Territory {
    var location: CodableCoordinate { centerCoordinate }
    var radius: Double { radiusMeters }
    var ownerFaction: Faction? { controllingFaction }
    var type: TerritoryType { .riftNode }
    var resources: TerritoryResources {
        TerritoryResources(goldPerHour: 50 * fortificationLevel, essencePerHour: 10 * fortificationLevel, essenceType: .norse, riftDustPerHour: 5 * fortificationLevel)
    }
    var structures: [TerritoryStructure] { [] }
}

// MARK: - TerritoryStructure
struct TerritoryStructure: Identifiable, Codable {
    let id: UUID
    let type: StructureType
    var level: Int
    var health: Int = 100
    var maxHealth: Int = 100
}

