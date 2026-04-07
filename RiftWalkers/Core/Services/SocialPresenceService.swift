import Foundation
import SwiftUI
import CoreLocation
import Combine

// MARK: - Social Presence & Anti-Loneliness Engine
// Pokemon GO's biggest retention killer: the game gets lonely.
// This service ensures players always have someone to play with:
// 1. AI Raid Partners — solo players can do group content with AI companions
// 2. Async Co-op — leave creatures to help friends overnight
// 3. Proximity Discovery — "3 walkers nearby" without exact location
// 4. SharePlay-ready for virtual co-walking

final class SocialPresenceService: ObservableObject {
    static let shared = SocialPresenceService()

    // Nearby walkers (privacy-safe: count only, no exact locations)
    @Published var nearbyWalkerCount: Int = 0
    @Published var nearbyWalkerActivity: [NearbyActivity] = []

    // AI Companions for solo raid content
    @Published var aiRaidPartners: [AIRaidPartner] = []

    // Async co-op
    @Published var incomingGifts: [AsyncGift] = []
    @Published var sentCreatureHelpers: [CreatureHelper] = []
    @Published var receivedHelpers: [CreatureHelper] = []

    // Social feed
    @Published var socialFeed: [SocialFeedItem] = []

    private let proxyBaseURL = "https://riftwalkers-api.heitkampnick23.workers.dev"
    private var proximityTimer: Timer?

    // MARK: - Models

    struct NearbyActivity: Identifiable {
        let id = UUID()
        let playerName: String
        let action: String // "caught a rare Norse creature", "won a PvP battle"
        let timeAgo: String
        let mythology: Mythology?
    }

    struct AIRaidPartner: Identifiable {
        let id = UUID()
        let name: String
        let personality: String
        let avatarIcon: String
        let level: Int
        let creatures: [AICreature]
        let dialogue: [String]
    }

    struct AICreature: Identifiable {
        let id = UUID()
        let speciesID: String
        let name: String
        let level: Int
        let element: Element
        let cp: Int
    }

    struct AsyncGift: Identifiable {
        let id = UUID()
        let senderName: String
        let senderIcon: String
        let giftType: GiftType
        let message: String
        let sentAt: Date
        var claimed: Bool = false
    }

    enum GiftType: String {
        case essences = "Essences"
        case spheres = "Capture Spheres"
        case gold = "Gold"
        case encouragement = "Encouragement"

        var icon: String {
            switch self {
            case .essences: return "sparkles"
            case .spheres: return "circle.circle.fill"
            case .gold: return "dollarsign.circle.fill"
            case .encouragement: return "heart.fill"
            }
        }

        var color: Color {
            switch self {
            case .essences: return .purple
            case .spheres: return .blue
            case .gold: return .yellow
            case .encouragement: return .pink
            }
        }
    }

    struct CreatureHelper: Identifiable {
        let id = UUID()
        let creatureName: String
        let creatureElement: Element
        let ownerName: String
        let helpType: HelpType
        let returnTime: Date
        var rewardEarned: Int = 0
    }

    enum HelpType: String {
        case battle = "Battle Aid"
        case defense = "Territory Guard"
        case gather = "Resource Gatherer"
    }

    struct SocialFeedItem: Identifiable {
        let id = UUID()
        let playerName: String
        let action: String
        let detail: String
        let timestamp: Date
        let icon: String
        let color: Color
    }

    private init() {
        generateAIPartners()
        generateSocialFeed()
        startProximitySimulation()
    }

    // MARK: - AI Raid Partners (for solo players)

    private func generateAIPartners() {
        aiRaidPartners = [
            AIRaidPartner(
                name: "Astrid the Bold",
                personality: "Aggressive attacker, loves Norse creatures",
                avatarIcon: "shield.fill",
                level: 18,
                creatures: [
                    AICreature(speciesID: "fenrir_pup", name: "Fenris", level: 20, element: .shadow, cp: 1450),
                    AICreature(speciesID: "valkyrie_scout", name: "Brynhild", level: 18, element: .light, cp: 1320),
                    AICreature(speciesID: "frost_drake", name: "Niflheim", level: 22, element: .ice, cp: 1680),
                ],
                dialogue: [
                    "By Odin's ravens, let's charge in!",
                    "My Fenris will tear through their defenses!",
                    "A worthy battle ahead. Stay sharp, Walker!",
                    "Victory or Valhalla!",
                ]
            ),
            AIRaidPartner(
                name: "Dr. Kenji Tanaka",
                personality: "Strategic healer, specialist in Japanese mythology",
                avatarIcon: "cross.circle.fill",
                level: 22,
                creatures: [
                    AICreature(speciesID: "kitsune_kit", name: "Akira", level: 24, element: .fire, cp: 1720),
                    AICreature(speciesID: "kodama_sprout", name: "Mori", level: 20, element: .nature, cp: 1180),
                    AICreature(speciesID: "tanuki", name: "Taro", level: 21, element: .earth, cp: 1350),
                ],
                dialogue: [
                    "Let me analyze their weakness first...",
                    "Akira, use your foxfire to distract them!",
                    "Patience wins battles. Let them come to us.",
                    "A perfectly executed strategy!",
                ]
            ),
            AIRaidPartner(
                name: "Amara Osei",
                personality: "Balanced fighter, expert in African mythology",
                avatarIcon: "sun.max.fill",
                level: 20,
                creatures: [
                    AICreature(speciesID: "anansi_trickster", name: "Kweku", level: 22, element: .shadow, cp: 1560),
                    AICreature(speciesID: "simba_cub", name: "Zuri", level: 19, element: .fire, cp: 1280),
                    AICreature(speciesID: "mami_wata", name: "Aya", level: 23, element: .water, cp: 1650),
                ],
                dialogue: [
                    "Anansi always has a trick ready!",
                    "The spirits of the ancestors guide us!",
                    "Together we are stronger than any rift beast!",
                    "Another victory for the Walker family!",
                ]
            ),
        ]
    }

    // MARK: - Async Co-op

    func sendCreatureToHelp(creatureName: String, element: Element, friendName: String, helpType: HelpType) {
        let helper = CreatureHelper(
            creatureName: creatureName,
            creatureElement: element,
            ownerName: "You",
            helpType: helpType,
            returnTime: Date().addingTimeInterval(8 * 3600) // Returns in 8 hours
        )
        sentCreatureHelpers.append(helper)

        // Simulate receiving a thank-you gift later
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.incomingGifts.append(AsyncGift(
                senderName: friendName,
                senderIcon: "person.circle.fill",
                giftType: .encouragement,
                message: "Thanks for the help! Your \(creatureName) was amazing!",
                sentAt: Date()
            ))
        }
    }

    func claimGift(_ gift: AsyncGift) {
        guard let index = incomingGifts.firstIndex(where: { $0.id == gift.id }) else { return }
        incomingGifts[index].claimed = true

        switch gift.giftType {
        case .gold: EconomyManager.shared.earn(gold: 500)
        case .essences: EconomyManager.shared.earn(gems: 10)
        case .spheres: break // Add to inventory
        case .encouragement: EconomyManager.shared.earn(gold: 100)
        }
    }

    // MARK: - Social Feed (makes the world feel alive)

    private func generateSocialFeed() {
        let names = ["RiftHunter99", "MythicMaya", "NorseKnight", "DragonSeeker", "ShadowWalker",
                     "CelticStorm", "OriginTracer", "ZenithRider", "PhoenixRise", "LunarHowl"]
        let actions: [(String, String, Color)] = [
            ("caught a Legendary", "sparkles", .yellow),
            ("won a PvP match", "trophy.fill", .orange),
            ("evolved their Fenrir", "arrow.up.circle.fill", .green),
            ("cleared a Rift Dungeon", "bolt.circle.fill", .purple),
            ("reached Level 25", "star.fill", .cyan),
            ("caught a Shiny creature", "sun.max.fill", .yellow),
            ("defended a territory", "shield.fill", .blue),
            ("completed 7-day streak", "flame.fill", .orange),
        ]

        socialFeed = (0..<12).map { i in
            let (action, icon, color) = actions[i % actions.count]
            return SocialFeedItem(
                playerName: names[i % names.count],
                action: action,
                detail: "",
                timestamp: Date().addingTimeInterval(-Double(i * 300 + Int.random(in: 0...600))),
                icon: icon,
                color: color
            )
        }
    }

    // MARK: - Proximity (privacy-safe)

    private func startProximitySimulation() {
        // In production: use server-side geohash bucketing
        // Players share a coarse geohash, server counts walkers per bucket
        proximityTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            // Simulate nearby walker count fluctuation
            let hour = Calendar.current.component(.hour, from: Date())
            let baseCount = hour >= 7 && hour <= 22 ? Int.random(in: 1...8) : Int.random(in: 0...2)
            self?.nearbyWalkerCount = baseCount
            self?.generateNearbyActivity()
        }
        // Initial
        nearbyWalkerCount = Int.random(in: 1...5)
        generateNearbyActivity()
        generateAsyncGifts()
    }

    private func generateNearbyActivity() {
        let actions = [
            "caught a rare creature",
            "is exploring Norse rifts",
            "won a PvP battle nearby",
            "claimed a territory",
            "is on a 5-day streak",
        ]
        let names = ["NearbyWalker", "LocalHero", "AreaGuardian", "Fellow Rift Walker"]
        let mythologies: [Mythology?] = [.norse, .greek, .japanese, nil, .celtic]

        nearbyWalkerActivity = (0..<min(nearbyWalkerCount, 3)).map { i in
            NearbyActivity(
                playerName: names[i % names.count],
                action: actions[i % actions.count],
                timeAgo: "\(Int.random(in: 1...30))m ago",
                mythology: mythologies[i % mythologies.count]
            )
        }
    }

    private func generateAsyncGifts() {
        incomingGifts = [
            AsyncGift(senderName: "MythicMaya", senderIcon: "person.circle.fill",
                     giftType: .gold, message: "Great battle yesterday! Here's some gold.", sentAt: Date().addingTimeInterval(-3600)),
            AsyncGift(senderName: "NorseKnight", senderIcon: "person.circle.fill",
                     giftType: .encouragement, message: "Keep up the streak! You're doing amazing!", sentAt: Date().addingTimeInterval(-7200)),
        ]

        receivedHelpers = [
            CreatureHelper(creatureName: "Shadow Wolf", creatureElement: .shadow, ownerName: "RiftHunter99",
                          helpType: .defense, returnTime: Date().addingTimeInterval(4 * 3600), rewardEarned: 250),
        ]
    }

    // MARK: - AI Partner Selection for Raids

    func getPartner(preferredElement: Element? = nil) -> AIRaidPartner {
        if let element = preferredElement {
            return aiRaidPartners.first { partner in
                partner.creatures.contains { $0.element == element }
            } ?? aiRaidPartners.randomElement()!
        }
        return aiRaidPartners.randomElement()!
    }
}
