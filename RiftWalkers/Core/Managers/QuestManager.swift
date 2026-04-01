import Foundation
import Combine

// MARK: - Quest Manager
// Researched: Genshin Impact's layered quest system:
// - Daily Commissions (4/day) = guaranteed daily engagement
// - Story Quests = narrative hook, drip-fed with updates
// - World Quests = exploration rewards
// - Events = FOMO + seasonal freshness
// - Reputation = long-term grind
//
// Key insight: Players need BOTH short-term (daily) and long-term (story) goals.
// If they only have dailies, it feels like a chore. Only story = they finish and leave.

final class QuestManager: ObservableObject {
    static let shared = QuestManager()

    @Published var activeQuests: [Quest] = []
    @Published var dailyQuests: [Quest] = []
    @Published var weeklyQuests: [Quest] = []
    @Published var storyQuests: [Quest] = []
    @Published var eventQuests: [Quest] = []
    @Published var completedQuestCount: Int = 0

    private let progression = ProgressionManager.shared
    private let economy = EconomyManager.shared
    private let haptics = HapticsService.shared
    private let audio = AudioService.shared

    private init() {
        generateDailyQuests()
        generateWeeklyQuests()
        loadStoryQuests()
    }

    // MARK: - Daily Quest Generation
    // Rotate daily at midnight local time. 4 quests + 1 bonus for completing all 4.

    func generateDailyQuests() {
        dailyQuests = [
            Quest(
                id: UUID(), title: "Morning Patrol",
                description: "Capture 3 creatures to survey rift activity.",
                type: .daily, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Capture 3 creatures", type: .catchCreature, targetCount: 3, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 200, gold: 150, riftGems: 5, items: [], essences: [:], battlePassXP: 100),
                expiresAt: endOfDay(), isCompleted: false, isActive: true, requiredLevel: 1,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
            Quest(
                id: UUID(), title: "Walker's Exercise",
                description: "Walk 2km to strengthen your rift bond.",
                type: .daily, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Walk 2km", type: .walkDistance, targetCount: 2000, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 250, gold: 100, riftGems: 5, items: ["incense_x1"], essences: [:], battlePassXP: 100),
                expiresAt: endOfDay(), isCompleted: false, isActive: true, requiredLevel: 1,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
            Quest(
                id: UUID(), title: "Battle Training",
                description: "Win 2 battles to hone your creatures' skills.",
                type: .daily, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Win 2 battles", type: .defeatCreature, targetCount: 2, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 300, gold: 200, riftGems: 5, items: [], essences: [:], battlePassXP: 100),
                expiresAt: endOfDay(), isCompleted: false, isActive: true, requiredLevel: 3,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
            Quest(
                id: UUID(), title: "Territory Scout",
                description: "Visit 2 territories to gather intel.",
                type: .daily, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Visit 2 territories", type: .visitTerritory, targetCount: 2, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 200, gold: 150, riftGems: 5, items: [], essences: [:], battlePassXP: 100),
                expiresAt: endOfDay(), isCompleted: false, isActive: true, requiredLevel: 5,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
        ]
    }

    func generateWeeklyQuests() {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfDay()) ?? Date()

        weeklyQuests = [
            Quest(
                id: UUID(), title: "Rift Researcher",
                description: "Capture 20 creatures this week for the research archive.",
                type: .weekly, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Capture 20 creatures", type: .catchCreature, targetCount: 20, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 1500, gold: 1000, riftGems: 30, items: ["ultra_sphere_x5"], essences: [:], battlePassXP: 500),
                expiresAt: endOfWeek, isCompleted: false, isActive: true, requiredLevel: 1,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
            Quest(
                id: UUID(), title: "Rift Walker Marathon",
                description: "Walk 25km this week. The rifts respond to movement.",
                type: .weekly, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Walk 25km", type: .walkDistance, targetCount: 25000, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 2000, gold: 800, riftGems: 50, items: ["rift_key_x2"], essences: [:], battlePassXP: 750),
                expiresAt: endOfWeek, isCompleted: false, isActive: true, requiredLevel: 1,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
            Quest(
                id: UUID(), title: "Mythology Expert",
                description: "Capture creatures from 5 different mythologies.",
                type: .weekly, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Capture from 5 mythologies", type: .catchMythologyCreature, targetCount: 5, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 1800, gold: 1200, riftGems: 40, items: [], essences: [:], battlePassXP: 600),
                expiresAt: endOfWeek, isCompleted: false, isActive: true, requiredLevel: 5,
                chainID: nil, chainIndex: nil, narrativeText: nil
            ),
        ]
    }

    // MARK: - Story Quests
    // Main narrative: The rifts between mythological realms are opening.
    // Player must discover why and choose how to respond (faction-based branching).

    private func loadStoryQuests() {
        storyQuests = [
            Quest(
                id: UUID(), title: "The First Rift",
                description: "A strange shimmer appeared near your location. Investigate the anomaly.",
                type: .story, mythology: nil,
                objectives: [
                    QuestObjective(id: UUID(), description: "Walk to the rift anomaly", type: .walkDistance, targetCount: 100, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil),
                    QuestObjective(id: UUID(), description: "Capture your first creature", type: .catchCreature, targetCount: 1, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 500, gold: 500, riftGems: 25, items: ["great_sphere_x10", "potion_x5"], essences: [:], battlePassXP: 200),
                expiresAt: nil, isCompleted: false, isActive: true, requiredLevel: 1,
                chainID: "main_story", chainIndex: 1,
                narrativeText: """
                You feel it before you see it — a vibration in the air, like the world is holding its breath. \
                Then the shimmer appears: a tear in reality itself, edges crackling with ancient energy.

                Through the rift, you glimpse impossible things — creatures from legends, myths your \
                grandmother told you were just stories. But they're real. They're here.

                And they're looking right at you.

                Welcome, Rift Walker. The mythic realms are bleeding into our world. \
                Whether you protect it, harness it, or seek balance — that choice is yours.
                """
            ),
            Quest(
                id: UUID(), title: "Echoes of Olympus",
                description: "Greek mythological creatures have been spotted. Track them down.",
                type: .mythology, mythology: .greek,
                objectives: [
                    QuestObjective(id: UUID(), description: "Capture 3 Greek creatures", type: .catchMythologyCreature, targetCount: 3, currentCount: 0, targetSpecies: nil, targetMythology: .greek, targetLocation: nil, targetRadius: nil),
                    QuestObjective(id: UUID(), description: "Win a battle using a Greek creature", type: .defeatCreature, targetCount: 1, currentCount: 0, targetSpecies: nil, targetMythology: .greek, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 800, gold: 600, riftGems: 15, items: [], essences: [.greek: 50], battlePassXP: 300),
                expiresAt: nil, isCompleted: false, isActive: false, requiredLevel: 3,
                chainID: "greek_story", chainIndex: 1,
                narrativeText: """
                The air smells of olives and sea salt. Somewhere nearby, you hear the distant \
                clash of bronze on bronze. The Greek rift is open, and Olympus is leaking into the mortal world.

                A weathered stone tablet materializes before you, inscribed with ancient Greek: \
                "Prove yourself worthy. Capture the children of myth."
                """
            ),
            Quest(
                id: UUID(), title: "Whispers of Yggdrasil",
                description: "Norse creatures stir as Yggdrasil's roots crack through the rift.",
                type: .mythology, mythology: .norse,
                objectives: [
                    QuestObjective(id: UUID(), description: "Capture 3 Norse creatures", type: .catchMythologyCreature, targetCount: 3, currentCount: 0, targetSpecies: nil, targetMythology: .norse, targetLocation: nil, targetRadius: nil),
                    QuestObjective(id: UUID(), description: "Explore during night time", type: .walkDistance, targetCount: 1000, currentCount: 0, targetSpecies: nil, targetMythology: nil, targetLocation: nil, targetRadius: nil)
                ],
                rewards: QuestRewards(experience: 800, gold: 600, riftGems: 15, items: [], essences: [.norse: 50], battlePassXP: 300),
                expiresAt: nil, isCompleted: false, isActive: false, requiredLevel: 3,
                chainID: "norse_story", chainIndex: 1,
                narrativeText: """
                Frost creeps across the ground despite the season. The world tree groans in a language \
                older than words, and from the frost emerges a rune, glowing with cold blue fire.

                "Walk the path of the Allfather," it reads. "The nine realms bleed, and only \
                those brave enough to walk the frost will understand why."
                """
            ),
        ]
    }

    // MARK: - Quest Progress Updates

    func updateObjective(type: ObjectiveType, increment: Int = 1, mythology: Mythology? = nil, species: String? = nil) {
        var allQuests = dailyQuests + weeklyQuests + storyQuests + eventQuests

        for questIndex in allQuests.indices {
            guard allQuests[questIndex].isActive && !allQuests[questIndex].isCompleted else { continue }

            for objIndex in allQuests[questIndex].objectives.indices {
                let obj = allQuests[questIndex].objectives[objIndex]
                guard obj.type == type && !obj.isComplete else { continue }

                // Check mythology filter
                if let targetMyth = obj.targetMythology, targetMyth != mythology { continue }
                // Check species filter
                if let targetSpecies = obj.targetSpecies, targetSpecies != species { continue }

                allQuests[questIndex].objectives[objIndex].currentCount += increment
            }

            // Check if quest is now complete
            let allObjectivesComplete = allQuests[questIndex].objectives.allSatisfy { $0.isComplete }
            if allObjectivesComplete && !allQuests[questIndex].isCompleted {
                completeQuest(&allQuests[questIndex])
            }
        }

        // Reassign back to categories
        syncQuests(allQuests)
    }

    private func completeQuest(_ quest: inout Quest) {
        quest.isCompleted = true
        completedQuestCount += 1

        // Award rewards
        let rewards = quest.rewards
        progression.awardXP(amount: rewards.experience, source: .questComplete)
        economy.earn(gold: rewards.gold, gems: rewards.riftGems)
        for (myth, amount) in rewards.essences {
            economy.earn(essence: (myth, amount))
        }
        progression.awardBattlePassXP(rewards.battlePassXP)

        audio.playSFX(.questComplete)
        haptics.notification(.success)

        // Activate next quest in chain
        if let chainID = quest.chainID, let chainIndex = quest.chainIndex {
            activateNextInChain(chainID: chainID, afterIndex: chainIndex)
        }
    }

    private func activateNextInChain(chainID: String, afterIndex: Int) {
        if let nextIndex = storyQuests.firstIndex(where: { $0.chainID == chainID && $0.chainIndex == afterIndex + 1 }) {
            storyQuests[nextIndex].isActive = true
        }
    }

    private func syncQuests(_ allQuests: [Quest]) {
        dailyQuests = allQuests.filter { $0.type == .daily }
        weeklyQuests = allQuests.filter { $0.type == .weekly }
        storyQuests = allQuests.filter { $0.type == .story || $0.type == .mythology }
        eventQuests = allQuests.filter { $0.type == .event }
    }

    // MARK: - Helpers

    private func endOfDay() -> Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
    }

    private func startOfDay() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
}
