import Foundation
import SwiftUI

final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var achievements: [TrackedAchievement] = []
    @Published var recentUnlock: TrackedAchievement?

    private let audio = AudioService.shared
    private let haptics = HapticsService.shared

    private init() {
        loadAchievements()
    }

    // MARK: - Achievement Definitions

    static let allDefinitions: [AchievementDefinition] = {
        var defs: [AchievementDefinition] = []

        // ── Collection ──
        defs.append(AchievementDefinition(
            id: "catch_first", name: "First Catch", description: "Capture your first creature",
            icon: "pawprint.fill", category: .collection,
            tiers: [.init(tier: 1, requirement: 1, rewardXP: 100, rewardGold: 50, rewardTitle: nil)]
        ))
        defs.append(AchievementDefinition(
            id: "catch_many", name: "Creature Collector", description: "Capture creatures",
            icon: "square.grid.3x3.fill", category: .collection,
            tiers: [
                .init(tier: 1, requirement: 10, rewardXP: 200, rewardGold: 100, rewardTitle: nil),
                .init(tier: 2, requirement: 50, rewardXP: 500, rewardGold: 250, rewardTitle: "Collector"),
                .init(tier: 3, requirement: 200, rewardXP: 1500, rewardGold: 750, rewardTitle: "Master Collector"),
                .init(tier: 4, requirement: 1000, rewardXP: 5000, rewardGold: 2000, rewardTitle: "Legendary Collector"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "unique_species", name: "Dex Completionist", description: "Discover unique species",
            icon: "book.pages.fill", category: .collection,
            tiers: [
                .init(tier: 1, requirement: 10, rewardXP: 300, rewardGold: 200, rewardTitle: nil),
                .init(tier: 2, requirement: 30, rewardXP: 800, rewardGold: 500, rewardTitle: "Scholar"),
                .init(tier: 3, requirement: 60, rewardXP: 2000, rewardGold: 1000, rewardTitle: "Myth Expert"),
                .init(tier: 4, requirement: 88, rewardXP: 10000, rewardGold: 5000, rewardTitle: "Rift Encyclopedist"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "shiny_catch", name: "Lucky Find", description: "Catch shiny creatures",
            icon: "sparkles", category: .collection,
            tiers: [
                .init(tier: 1, requirement: 1, rewardXP: 500, rewardGold: 300, rewardTitle: "Lucky"),
                .init(tier: 2, requirement: 5, rewardXP: 1500, rewardGold: 1000, rewardTitle: nil),
                .init(tier: 3, requirement: 25, rewardXP: 5000, rewardGold: 3000, rewardTitle: "Shiny Hunter"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "evolve_count", name: "Evolution Expert", description: "Evolve creatures",
            icon: "arrow.triangle.2.circlepath", category: .collection,
            tiers: [
                .init(tier: 1, requirement: 1, rewardXP: 200, rewardGold: 100, rewardTitle: nil),
                .init(tier: 2, requirement: 10, rewardXP: 800, rewardGold: 400, rewardTitle: nil),
                .init(tier: 3, requirement: 50, rewardXP: 3000, rewardGold: 1500, rewardTitle: "Evolutionist"),
            ]
        ))

        // ── Battle ──
        defs.append(AchievementDefinition(
            id: "pvp_wins", name: "Gladiator", description: "Win PvP battles",
            icon: "figure.fencing", category: .battle,
            tiers: [
                .init(tier: 1, requirement: 1, rewardXP: 150, rewardGold: 100, rewardTitle: nil),
                .init(tier: 2, requirement: 25, rewardXP: 800, rewardGold: 500, rewardTitle: "Duelist"),
                .init(tier: 3, requirement: 100, rewardXP: 3000, rewardGold: 1500, rewardTitle: "Champion"),
                .init(tier: 4, requirement: 500, rewardXP: 10000, rewardGold: 5000, rewardTitle: "Legendary Champion"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "battles_total", name: "Battle Veteran", description: "Complete battles",
            icon: "shield.lefthalf.filled", category: .battle,
            tiers: [
                .init(tier: 1, requirement: 10, rewardXP: 200, rewardGold: 100, rewardTitle: nil),
                .init(tier: 2, requirement: 100, rewardXP: 1000, rewardGold: 500, rewardTitle: "Veteran"),
                .init(tier: 3, requirement: 500, rewardXP: 5000, rewardGold: 2500, rewardTitle: "War Hardened"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "rift_dungeons", name: "Rift Diver", description: "Clear Rift Dungeons",
            icon: "tornado", category: .battle,
            tiers: [
                .init(tier: 1, requirement: 5, rewardXP: 300, rewardGold: 200, rewardTitle: nil),
                .init(tier: 2, requirement: 25, rewardXP: 1200, rewardGold: 700, rewardTitle: "Rift Diver"),
                .init(tier: 3, requirement: 100, rewardXP: 5000, rewardGold: 3000, rewardTitle: "Rift Master"),
            ]
        ))

        // ── Exploration ──
        defs.append(AchievementDefinition(
            id: "distance_walked", name: "Rift Walker", description: "Walk total distance (km)",
            icon: "figure.walk", category: .exploration,
            tiers: [
                .init(tier: 1, requirement: 1, rewardXP: 100, rewardGold: 50, rewardTitle: nil),
                .init(tier: 2, requirement: 10, rewardXP: 500, rewardGold: 250, rewardTitle: nil),
                .init(tier: 3, requirement: 50, rewardXP: 2000, rewardGold: 1000, rewardTitle: "Wanderer"),
                .init(tier: 4, requirement: 200, rewardXP: 8000, rewardGold: 4000, rewardTitle: "World Walker"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "territories", name: "Territory Lord", description: "Claim territories",
            icon: "flag.fill", category: .exploration,
            tiers: [
                .init(tier: 1, requirement: 1, rewardXP: 200, rewardGold: 150, rewardTitle: nil),
                .init(tier: 2, requirement: 10, rewardXP: 1000, rewardGold: 600, rewardTitle: "Territory Lord"),
                .init(tier: 3, requirement: 50, rewardXP: 5000, rewardGold: 3000, rewardTitle: "Conqueror"),
            ]
        ))

        // ── Social ──
        defs.append(AchievementDefinition(
            id: "daily_streak", name: "Dedicated", description: "Maintain daily login streak",
            icon: "flame.fill", category: .social,
            tiers: [
                .init(tier: 1, requirement: 7, rewardXP: 300, rewardGold: 200, rewardTitle: nil),
                .init(tier: 2, requirement: 30, rewardXP: 1500, rewardGold: 800, rewardTitle: "The Dedicated"),
                .init(tier: 3, requirement: 100, rewardXP: 5000, rewardGold: 3000, rewardTitle: "Rift Devotee"),
                .init(tier: 4, requirement: 365, rewardXP: 20000, rewardGold: 10000, rewardTitle: "Eternal Walker"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "quests_done", name: "Quest Master", description: "Complete quests",
            icon: "checklist", category: .social,
            tiers: [
                .init(tier: 1, requirement: 5, rewardXP: 200, rewardGold: 100, rewardTitle: nil),
                .init(tier: 2, requirement: 25, rewardXP: 800, rewardGold: 400, rewardTitle: nil),
                .init(tier: 3, requirement: 100, rewardXP: 3000, rewardGold: 1500, rewardTitle: "Quest Master"),
            ]
        ))
        defs.append(AchievementDefinition(
            id: "level_up", name: "Ascendant", description: "Reach player levels",
            icon: "arrow.up.circle.fill", category: .social,
            tiers: [
                .init(tier: 1, requirement: 5, rewardXP: 200, rewardGold: 150, rewardTitle: nil),
                .init(tier: 2, requirement: 15, rewardXP: 1000, rewardGold: 500, rewardTitle: nil),
                .init(tier: 3, requirement: 30, rewardXP: 3000, rewardGold: 1500, rewardTitle: "Ascendant"),
                .init(tier: 4, requirement: 50, rewardXP: 10000, rewardGold: 5000, rewardTitle: "Transcendent"),
            ]
        ))

        // ── Mythology ──
        for myth in Mythology.allCases {
            defs.append(AchievementDefinition(
                id: "myth_\(myth.rawValue.lowercased())", name: "\(myth.rawValue) Adept",
                description: "Catch \(myth.rawValue) creatures",
                icon: myth.icon, category: .mythology,
                tiers: [
                    .init(tier: 1, requirement: 3, rewardXP: 200, rewardGold: 100, rewardTitle: nil),
                    .init(tier: 2, requirement: 10, rewardXP: 800, rewardGold: 400, rewardTitle: "\(myth.rawValue) Adept"),
                    .init(tier: 3, requirement: 30, rewardXP: 3000, rewardGold: 1500, rewardTitle: "\(myth.rawValue) Master"),
                ]
            ))
        }

        return defs
    }()

    // MARK: - Check Progress

    func checkAll(player: Player, creatures: [Creature]) {
        var anyNew = false

        for def in Self.allDefinitions {
            let currentValue = metricValue(for: def.id, player: player, creatures: creatures)
            let idx = achievements.firstIndex(where: { $0.definitionId == def.id })

            if let idx {
                let old = achievements[idx]
                if currentValue != old.currentValue {
                    achievements[idx].currentValue = currentValue
                    let newTier = def.currentTier(for: currentValue)
                    if newTier > old.unlockedTier {
                        achievements[idx].unlockedTier = newTier
                        achievements[idx].unlockedDate = Date()
                        anyNew = true
                        let tierDef = def.tiers[newTier - 1]
                        triggerUnlock(achievements[idx], tierDef: tierDef)
                    }
                }
            } else {
                let tier = def.currentTier(for: currentValue)
                let tracked = TrackedAchievement(
                    definitionId: def.id,
                    currentValue: currentValue,
                    unlockedTier: tier,
                    unlockedDate: tier > 0 ? Date() : nil
                )
                achievements.append(tracked)
                if tier > 0 {
                    anyNew = true
                    let tierDef = def.tiers[tier - 1]
                    triggerUnlock(tracked, tierDef: tierDef)
                }
            }
        }

        if anyNew {
            save()
        }
    }

    private func metricValue(for id: String, player: Player, creatures: [Creature]) -> Int {
        switch id {
        case "catch_first", "catch_many": return player.creaturesCaught
        case "unique_species": return Set(creatures.map(\.speciesID)).count
        case "shiny_catch": return creatures.filter(\.isShiny).count
        case "evolve_count": return creatures.filter { $0.evolutionStage > 1 }.count
        case "pvp_wins": return player.pvpWins
        case "battles_total": return player.pvpWins + player.pvpLosses
        case "rift_dungeons": return player.riftsCleared
        case "distance_walked": return Int(player.totalDistanceWalked / 1000)
        case "territories": return player.territoriesClaimed
        case "daily_streak": return player.dailyStreak
        case "quests_done": return player.questsCompleted
        case "level_up": return player.level
        default:
            // Mythology-specific: myth_norse, myth_greek, etc.
            if id.hasPrefix("myth_") {
                let mythRaw = String(id.dropFirst(5))
                if let myth = Mythology.allCases.first(where: { $0.rawValue.lowercased() == mythRaw }) {
                    return creatures.filter { $0.mythology == myth }.count
                }
            }
            return 0
        }
    }

    private func triggerUnlock(_ achievement: TrackedAchievement, tierDef: AchievementDefinition.Tier) {
        audio.playSFX(.achievementUnlock)
        haptics.notification(.success)
        recentUnlock = achievement
        NotificationCenter.default.post(name: .achievementUnlocked, object: achievement)

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.recentUnlock?.definitionId == achievement.definitionId {
                withAnimation { self?.recentUnlock = nil }
            }
        }
    }

    // MARK: - Helpers

    func definition(for id: String) -> AchievementDefinition? {
        Self.allDefinitions.first(where: { $0.id == id })
    }

    var totalUnlocked: Int {
        achievements.filter { $0.unlockedTier > 0 }.count
    }

    var totalPossible: Int {
        Self.allDefinitions.flatMap(\.tiers).count
    }

    var totalTiersUnlocked: Int {
        achievements.reduce(0) { $0 + $1.unlockedTier }
    }

    func achievements(for category: AchievementDefinition.Category) -> [(AchievementDefinition, TrackedAchievement?)] {
        Self.allDefinitions
            .filter { $0.category == category }
            .map { def in (def, achievements.first(where: { $0.definitionId == def.id })) }
    }

    // MARK: - Persistence

    private let saveKey = "riftwalkers_achievements"

    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([TrackedAchievement].self, from: data) {
            achievements = saved
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
}

// MARK: - Models

struct AchievementDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: Category
    let tiers: [Tier]

    struct Tier {
        let tier: Int
        let requirement: Int
        let rewardXP: Int
        let rewardGold: Int
        let rewardTitle: String?
    }

    enum Category: String, CaseIterable, Identifiable {
        case collection = "Collection"
        case battle = "Battle"
        case exploration = "Exploration"
        case social = "Social"
        case mythology = "Mythology"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .collection: return "square.grid.3x3.fill"
            case .battle: return "shield.lefthalf.filled"
            case .exploration: return "map.fill"
            case .social: return "person.2.fill"
            case .mythology: return "book.fill"
            }
        }

        var color: Color {
            switch self {
            case .collection: return .cyan
            case .battle: return .red
            case .exploration: return .green
            case .social: return .orange
            case .mythology: return .purple
            }
        }
    }

    func currentTier(for value: Int) -> Int {
        var highest = 0
        for t in tiers {
            if value >= t.requirement { highest = t.tier }
        }
        return highest
    }

    func nextTier(after current: Int) -> Tier? {
        tiers.first(where: { $0.tier == current + 1 })
    }
}

struct TrackedAchievement: Codable, Identifiable {
    var id: String { definitionId }
    let definitionId: String
    var currentValue: Int
    var unlockedTier: Int
    var unlockedDate: Date?
}
