import Foundation
import Combine

// MARK: - Progression Manager
// Researched: The "one more" loop from Diablo + Pokemon GO's collection completionism.
// Players need MULTIPLE progression vectors to prevent any single one from stalling:
// 1. Player Level (XP from everything)
// 2. Creature Collection (% completion drives completionists)
// 3. Creature Power (leveling + evolution)
// 4. Territory Control (competitive map dominance)
// 5. Battle Pass (seasonal FOMO)
// 6. Achievement System (long-tail goals)
// 7. Guild Progression (social commitment)
// 8. PvP Rating (competitive ladder)

final class ProgressionManager: ObservableObject {
    static let shared = ProgressionManager()

    @Published var player: Player
    @Published var collectionProgress: Double = 0
    @Published var mythologyProgress: [Mythology: Double] = [:]
    @Published var weeklyXPEarned: Int = 0
    @Published var dailyActivitiesCompleted: Int = 0

    private let economy = EconomyManager.shared
    private let haptics = HapticsService.shared
    private let audio = AudioService.shared
    private var cancellables = Set<AnyCancellable>()

    // XP sources and multipliers
    private let xpMultipliers: [XPSource: Double] = [
        .creatureCapture: 1.0,
        .creatureEvolve: 3.0,
        .battleWin: 1.5,
        .questComplete: 2.0,
        .riftDungeon: 2.5,
        .territoryCapture: 2.0,
        .pvpWin: 1.8,
        .dailyLogin: 0.5,
        .walkingDistance: 0.3,    // per 100m
        .newCreatureDiscovery: 5.0,
    ]

    private init() {
        // Initialize with default player
        self.player = Player(
            id: UUID(),
            username: "",
            displayName: "New Walker",
            avatarURL: nil,
            level: 1,
            experience: 0,
            title: "Novice Rift Walker",
            gold: 1000,
            riftGems: 50,
            essences: [:],
            riftDust: 100,
            creatures: [],
            activeParty: [],
            creaturesSeen: 0,
            creaturesCaught: 0,
            items: [],
            maxInventorySlots: 250,
            guildID: nil,
            friendIDs: [],
            pvpRating: 1000,
            pvpWins: 0,
            pvpLosses: 0,
            questsCompleted: 0,
            riftsCleared: 0,
            territoriesClaimed: 0,
            totalDistanceWalked: 0,
            dailyStreak: 0,
            lastLoginDate: nil,
            achievements: [],
            battlePassTier: 0,
            battlePassPremium: false,
            joinDate: Date(),
            totalPlayTime: 0,
            faction: nil
        )
    }

    // MARK: - XP System

    enum XPSource {
        case creatureCapture
        case creatureEvolve
        case battleWin
        case questComplete
        case riftDungeon
        case territoryCapture
        case pvpWin
        case dailyLogin
        case walkingDistance
        case newCreatureDiscovery
    }

    func awardXP(amount: Int, source: XPSource) {
        let multiplier = xpMultipliers[source] ?? 1.0
        let totalXP = Int(Double(amount) * multiplier)

        player.experience += totalXP
        weeklyXPEarned += totalXP

        // Check for level up
        while player.experience >= player.experienceToNextLevel {
            player.experience -= player.experienceToNextLevel
            levelUp()
        }
    }

    private func levelUp() {
        player.level += 1
        haptics.levelUp()
        audio.playSFX(.levelUp)

        // Level rewards
        let goldReward = player.level * 100
        let gemReward = player.level % 5 == 0 ? 25 : 5  // Bonus every 5 levels
        economy.earn(gold: goldReward, gems: gemReward)

        // Unlock features at specific levels
        let unlocks = levelUnlocks[player.level]
        if let unlock = unlocks {
            NotificationCenter.default.post(
                name: .playerLeveledUp,
                object: nil,
                userInfo: ["level": player.level, "unlock": unlock]
            )
        }

        // Update title based on level
        player.title = titleForLevel(player.level)

        // Expand inventory every 10 levels
        if player.level % 10 == 0 {
            player.maxInventorySlots += 50
        }

        checkAchievements()
    }

    // MARK: - Level Unlocks (Drip-feed features to prevent overwhelming new players)
    // Researched: Clash Royale's arena unlock system. New mechanics every few levels.

    var levelUnlocks: [Int: String] {
        [
            2: "Capture Spheres unlocked!",
            3: "Quests unlocked!",
            5: "Territories unlocked! Claim your first territory.",
            7: "Crafting unlocked!",
            8: "Trading unlocked! Trade creatures with friends.",
            10: "PvP Battles unlocked! Test your strength.",
            12: "Guilds unlocked! Join or create a guild.",
            15: "Rift Dungeons unlocked! Challenge the rifts.",
            18: "Advanced crafting unlocked!",
            20: "Faction selection unlocked! Choose your allegiance.",
            25: "Raid Battles unlocked! Team up against bosses.",
            30: "Legendary Rift Dungeons unlocked!",
            35: "Mythic Rift Dungeons unlocked!",
            40: "Primordial Hunts unlocked!",
        ]
    }

    // MARK: - Title System

    func titleForLevel(_ level: Int) -> String {
        switch level {
        case 1...4: return "Novice Rift Walker"
        case 5...9: return "Apprentice Walker"
        case 10...14: return "Rift Scout"
        case 15...19: return "Rift Hunter"
        case 20...24: return "Rift Warden"
        case 25...29: return "Rift Commander"
        case 30...34: return "Myth Slayer"
        case 35...39: return "Rift Master"
        case 40...44: return "Legendary Walker"
        case 45...49: return "Mythic Champion"
        case 50: return "Primordial Walker"
        default: return "Ascended Walker"
        }
    }

    // MARK: - Collection Tracking

    func updateCollectionProgress() {
        let totalSpecies = SpeciesDatabase.shared.species.count
        let caught = player.creaturesCaught
        collectionProgress = Double(caught) / Double(totalSpecies)

        // Per-mythology progress
        for mythology in Mythology.allCases {
            let mythSpecies = SpeciesDatabase.shared.speciesForMythology(mythology)
            let mythCaught = 0 // Would track per-myth catches
            mythologyProgress[mythology] = Double(mythCaught) / Double(max(1, mythSpecies.count))
        }
    }

    // MARK: - Creature Management

    func addCreature(_ creature: Creature) {
        player.creatures.append(creature.id)
        player.creaturesCaught += 1
        awardXP(amount: 100, source: .creatureCapture)
        economy.earn(gold: 25, essence: (creature.mythology, creature.rarity.stars * 3))

        // New species bonus
        let isNew = player.creaturesSeen < player.creaturesCaught
        if isNew {
            player.creaturesSeen += 1
            awardXP(amount: 500, source: .newCreatureDiscovery)
            audio.playSFX(.rareDrop)
        }

        updateCollectionProgress()
        checkAchievements()
    }

    func evolveCreature(_ creature: inout Creature) -> Bool {
        guard creature.canEvolve,
              let cost = creature.evolutionCost,
              creature.level >= cost.requiredLevel else { return false }

        guard economy.spend(
            gold: cost.goldCost,
            essence: (creature.mythology, cost.essenceCost)
        ) else { return false }

        // Get evolution target
        guard let species = SpeciesDatabase.shared.getSpecies(creature.speciesID),
              let evolvedID = species.evolvesInto,
              let evolvedSpecies = SpeciesDatabase.shared.getSpecies(evolvedID) else { return false }

        // Apply evolution
        creature.speciesID = evolvedSpecies.id
        creature.name = evolvedSpecies.name
        creature.baseHP = evolvedSpecies.baseHP
        creature.baseAttack = evolvedSpecies.baseAttack
        creature.baseDefense = evolvedSpecies.baseDefense
        creature.baseSpeed = evolvedSpecies.baseSpeed
        creature.baseSpecial = evolvedSpecies.baseSpecial
        creature.evolutionStage = evolvedSpecies.evolutionStage
        creature.canEvolve = evolvedSpecies.evolvesInto != nil
        creature.currentHP = creature.maxHP

        awardXP(amount: 500, source: .creatureEvolve)
        audio.playSFX(.evolution)
        haptics.levelUp()

        return true
    }

    // MARK: - Daily Login Streak
    // Researched: Every top-grossing mobile game uses this. 7-day cycle with escalating rewards.

    func processLogin() {
        let now = Date()
        let calendar = Calendar.current

        if let lastLogin = player.lastLoginDate {
            if calendar.isDateInYesterday(lastLogin) {
                // Continue streak
                player.dailyStreak += 1
            } else if !calendar.isDateInToday(lastLogin) {
                // Streak broken
                player.dailyStreak = 1
            }
            // Same day = no change
        } else {
            player.dailyStreak = 1
        }

        player.lastLoginDate = now
        awardXP(amount: 50 * player.dailyStreak, source: .dailyLogin)
    }

    // MARK: - Battle Pass Progression
    // Researched: Fortnite Battle Pass = $300M/quarter. FOMO + visible rewards = conversion.

    func awardBattlePassXP(_ amount: Int) {
        let xpPerTier = 1000
        var totalXP = amount

        while totalXP > 0 && player.battlePassTier < 100 {
            let needed = xpPerTier - (totalXP % xpPerTier)
            if totalXP >= needed {
                player.battlePassTier += 1
                totalXP -= needed
                // Claim tier reward automatically
            } else {
                break
            }
        }
    }

    // MARK: - Achievement Checking

    private func checkAchievements() {
        let potentialAchievements: [(String, String, String, AchievementTier, Bool, String?)] = [
            ("First Catch", "Capture your first creature", "circle.fill", .bronze, player.creaturesCaught >= 1, nil),
            ("Collector", "Capture 50 creatures", "square.grid.3x3.fill", .silver, player.creaturesCaught >= 50, nil),
            ("Master Collector", "Capture 500 creatures", "square.grid.3x3.fill", .gold, player.creaturesCaught >= 500, "Master Collector"),
            ("First Steps", "Walk 1km total", "figure.walk", .bronze, player.totalDistanceWalked >= 1000, nil),
            ("Marathon Walker", "Walk 100km total", "figure.walk", .gold, player.totalDistanceWalked >= 100000, "The Wanderer"),
            ("Territory Lord", "Claim 10 territories", "flag.fill", .silver, player.territoriesClaimed >= 10, "Territory Lord"),
            ("Rift Diver", "Clear 25 Rift Dungeons", "tornado", .silver, player.riftsCleared >= 25, "Rift Diver"),
            ("PvP Champion", "Win 100 PvP battles", "figure.fencing", .gold, player.pvpWins >= 100, "Champion"),
            ("Dedication", "Login 30 days in a row", "calendar", .gold, player.dailyStreak >= 30, "The Dedicated"),
            ("Myth Scholar", "Complete all mythology questlines", "book.fill", .platinum, false, "Myth Scholar"),
        ]

        for (name, desc, icon, tier, condition, rewardTitle) in potentialAchievements {
            let alreadyUnlocked = player.achievements.contains { $0.name == name && $0.isUnlocked }
            if condition && !alreadyUnlocked {
                let achievement = Achievement(
                    id: UUID(),
                    name: name,
                    description: desc,
                    icon: icon,
                    tier: tier,
                    isUnlocked: true,
                    unlockedDate: Date(),
                    rewardTitle: rewardTitle
                )
                player.achievements.append(achievement)
                audio.playSFX(.achievementUnlock)
                haptics.notification(.success)
            }
        }
    }

    // MARK: - Walking Rewards (Egg hatching / adventure sync style)

    func processWalkingDistance(_ meters: Double) {
        player.totalDistanceWalked += meters

        // Award XP per 100m
        let units = Int(meters / 100)
        if units > 0 {
            awardXP(amount: units * 10, source: .walkingDistance)
            economy.earn(gold: units * 5)
        }

        checkAchievements()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let playerLeveledUp = Notification.Name("playerLeveledUp")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}
