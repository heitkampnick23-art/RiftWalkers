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

    func generateDailyQuests() {
        dailyQuests = [
            makeQuest(
                title: "Morning Patrol",
                description: "Capture 3 creatures to survey rift activity.",
                type: .daily,
                objectives: [
                    makeObjective("Capture 3 creatures", type: .catchCreature, target: 3)
                ],
                xp: 200, stardust: 150, mythosTokens: 5,
                expiresAt: endOfDay()
            ),
            makeQuest(
                title: "Walker's Exercise",
                description: "Walk 2km to strengthen your rift bond.",
                type: .daily,
                objectives: [
                    makeObjective("Walk 2km", type: .walkDistance, target: 2000)
                ],
                xp: 250, stardust: 100, mythosTokens: 5,
                expiresAt: endOfDay()
            ),
            makeQuest(
                title: "Battle Training",
                description: "Win 2 battles to hone your creatures' skills.",
                type: .daily,
                objectives: [
                    makeObjective("Win 2 battles", type: .winBattle, target: 2)
                ],
                xp: 300, stardust: 200, mythosTokens: 5,
                expiresAt: endOfDay()
            ),
            makeQuest(
                title: "Territory Scout",
                description: "Visit 2 territories to gather intel.",
                type: .daily,
                objectives: [
                    makeObjective("Visit 2 territories", type: .visitPOI, target: 2)
                ],
                xp: 200, stardust: 150, mythosTokens: 5,
                expiresAt: endOfDay()
            ),
        ]
    }

    func generateWeeklyQuests() {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfDay()) ?? Date()

        weeklyQuests = [
            makeQuest(
                title: "Rift Researcher",
                description: "Capture 20 creatures this week for the research archive.",
                type: .weekly,
                objectives: [
                    makeObjective("Capture 20 creatures", type: .catchCreature, target: 20)
                ],
                xp: 1500, stardust: 1000, mythosTokens: 30,
                expiresAt: endOfWeek
            ),
            makeQuest(
                title: "Rift Walker Marathon",
                description: "Walk 25km this week. The rifts respond to movement.",
                type: .weekly,
                objectives: [
                    makeObjective("Walk 25km", type: .walkDistance, target: 25000)
                ],
                xp: 2000, stardust: 800, mythosTokens: 50,
                expiresAt: endOfWeek
            ),
            makeQuest(
                title: "Mythology Expert",
                description: "Capture creatures from 5 different mythologies.",
                type: .weekly,
                objectives: [
                    makeObjective("Capture from 5 mythologies", type: .catchCreatureOfMythology, target: 5)
                ],
                xp: 1800, stardust: 1200, mythosTokens: 40,
                expiresAt: endOfWeek
            ),
        ]
    }

    // MARK: - Story Quests

    private func loadStoryQuests() {
        storyQuests = [
            makeQuest(
                title: "The First Rift",
                description: "A strange shimmer appeared near your location. Investigate the anomaly.",
                type: .story,
                objectives: [
                    makeObjective("Walk to the rift anomaly", type: .walkDistance, target: 100),
                    makeObjective("Capture your first creature", type: .catchCreature, target: 1)
                ],
                xp: 500, stardust: 500, mythosTokens: 25,
                isMainStory: true, chapterIndex: 1
            ),
            makeQuest(
                title: "Echoes of Olympus",
                description: "Greek mythological creatures have been spotted. Track them down.",
                type: .mythology, mythology: .greek,
                objectives: [
                    makeObjective("Capture 3 Greek creatures", type: .catchCreatureOfMythology, target: 3, details: ["mythology": "greek"]),
                    makeObjective("Win a battle using a Greek creature", type: .winBattle, target: 1, details: ["mythology": "greek"])
                ],
                xp: 800, stardust: 600, mythosTokens: 15
            ),
            makeQuest(
                title: "Whispers of Yggdrasil",
                description: "Norse creatures stir as Yggdrasil's roots crack through the rift.",
                type: .mythology, mythology: .norse,
                objectives: [
                    makeObjective("Capture 3 Norse creatures", type: .catchCreatureOfMythology, target: 3, details: ["mythology": "norse"]),
                    makeObjective("Explore during night time", type: .walkDistance, target: 1000)
                ],
                xp: 800, stardust: 600, mythosTokens: 15
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
                if let targetMyth = obj.targetDetails["mythology"],
                   let myth = mythology, targetMyth != myth.rawValue.lowercased() { continue }

                allQuests[questIndex].objectives[objIndex].currentProgress += increment

                if allQuests[questIndex].isCompleted {
                    completeQuest(allQuests[questIndex])
                }
            }
        }

        // Sync back
        dailyQuests = allQuests.filter { $0.type == .daily }
        weeklyQuests = allQuests.filter { $0.type == .weekly }
        storyQuests = allQuests.filter { $0.type == .story || $0.type == .mythology }
        eventQuests = allQuests.filter { $0.type == .event }
    }

    func completeQuest(_ quest: Quest) {
        completedQuestCount += 1
        let rewards = quest.rewards

        progression.awardXP(amount: rewards.xp, source: .questComplete)
        economy.earn(gold: rewards.stardust)
        progression.awardBattlePassXP(100)

        haptics.levelUp()
        audio.playSFX(.achievementUnlock)
    }

    func abandonQuest(_ quest: Quest) {
        dailyQuests.removeAll { $0.id == quest.id }
        weeklyQuests.removeAll { $0.id == quest.id }
        storyQuests.removeAll { $0.id == quest.id }
        eventQuests.removeAll { $0.id == quest.id }
    }

    // MARK: - Helpers

    private func makeQuest(
        title: String,
        description: String,
        type: Quest.QuestType,
        mythology: Mythology? = nil,
        objectives: [QuestObjective],
        xp: Int, stardust: Int, mythosTokens: Int,
        expiresAt: Date? = nil,
        isMainStory: Bool = false,
        chapterIndex: Int? = nil
    ) -> Quest {
        Quest(
            id: UUID().uuidString,
            title: title,
            description: description,
            type: type,
            mythology: mythology,
            objectives: objectives,
            rewards: QuestRewards(xp: xp, stardust: stardust, mythosTokens: mythosTokens, items: [:], creatureTemplateID: nil),
            expiresAt: expiresAt,
            isMainStory: isMainStory,
            chapterIndex: chapterIndex ?? 0,
            prerequisiteQuestIDs: []
        )
    }

    private func makeObjective(
        _ description: String,
        type: QuestObjective.ObjectiveType,
        target: Int,
        details: [String: String] = [:]
    ) -> QuestObjective {
        QuestObjective(
            id: UUID().uuidString,
            description: description,
            type: type,
            currentProgress: 0,
            targetProgress: target,
            targetDetails: details
        )
    }

    private func endOfDay() -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? Date()
    }

    private func startOfDay() -> Date {
        Calendar.current.startOfDay(for: Date())
    }
}
