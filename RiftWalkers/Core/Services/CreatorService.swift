import Foundation
import Combine

// MARK: - Creator Service
// Feature #7: Creator Economy / UGC system.
// Researched: Roblox's creator economy ($800M+ paid to creators in 2023).
// Key insight: Players who CREATE content have 10x retention over passive consumers.
// Community-designed creatures add infinite content without dev cost.

final class CreatorService: ObservableObject {
    static let shared = CreatorService()

    // MARK: - Published State

    @Published var communityCreatures: [CreatureDesign] = []
    @Published var playerDesigns: [CreatureDesign] = []
    @Published var communityVotes: [CommunityVote] = []

    // MARK: - Models

    struct CreatureDesign: Identifiable, Codable {
        let id: UUID
        var creatorName: String
        var name: String
        var mythology: Mythology
        var element: Element
        var rarity: Rarity
        var description: String
        var artPrompt: String
        var voteCount: Int
        var isApproved: Bool
        var submittedAt: Date

        init(
            id: UUID = UUID(),
            creatorName: String,
            name: String,
            mythology: Mythology,
            element: Element,
            rarity: Rarity = .rare,
            description: String,
            artPrompt: String = "",
            voteCount: Int = 0,
            isApproved: Bool = false,
            submittedAt: Date = Date()
        ) {
            self.id = id
            self.creatorName = creatorName
            self.name = name
            self.mythology = mythology
            self.element = element
            self.rarity = rarity
            self.description = description
            self.artPrompt = artPrompt
            self.voteCount = voteCount
            self.isApproved = isApproved
            self.submittedAt = submittedAt
        }
    }

    struct CommunityVote: Identifiable, Codable {
        let id: UUID
        let designId: UUID
        let voterName: String
        let isUpvote: Bool
        let votedAt: Date

        init(id: UUID = UUID(), designId: UUID, voterName: String, isUpvote: Bool, votedAt: Date = Date()) {
            self.id = id
            self.designId = designId
            self.voterName = voterName
            self.isUpvote = isUpvote
            self.votedAt = votedAt
        }
    }

    // MARK: - Weekly Featured

    /// Top designs sorted by vote count, used for the weekly featured showcase.
    var topDesigns: [CreatureDesign] {
        communityCreatures
            .sorted { $0.voteCount > $1.voteCount }
            .prefix(10)
            .map { $0 }
    }

    /// Designs submitted within the current calendar week.
    var thisWeekDesigns: [CreatureDesign] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return communityCreatures.filter { $0.submittedAt >= startOfWeek }
    }

    /// The single featured design of the week (highest voted this week).
    var weeklyFeaturedDesign: CreatureDesign? {
        thisWeekDesigns
            .sorted { $0.voteCount > $1.voteCount }
            .first
    }

    // MARK: - Init

    private init() {
        loadSampleDesigns()
    }

    // MARK: - Submit Design

    struct SubmitResult {
        let design: CreatureDesign?
        let error: String?
        var success: Bool { design != nil }
    }

    func submitDesign(
        creatorName: String = "Player",
        name: String,
        mythology: Mythology,
        element: Element,
        rarity: Rarity = .rare,
        description: String
    ) -> SubmitResult {
        let moderation = ContentModerationService.shared

        // Check EULA acceptance
        guard moderation.hasAcceptedEULA else {
            return SubmitResult(design: nil, error: "You must accept the Terms of Use before submitting content.")
        }

        // Filter creature name
        let nameCheck = moderation.filterContent(name)
        if !nameCheck.isClean {
            return SubmitResult(design: nil, error: "Creature name contains inappropriate content. Please choose a different name.")
        }

        // Filter description
        let descCheck = moderation.filterContent(description)
        if !descCheck.isClean {
            return SubmitResult(design: nil, error: "Description contains inappropriate content. Please revise.")
        }

        // Filter creator name
        if !moderation.isUsernameAppropriate(creatorName) {
            return SubmitResult(design: nil, error: "Creator name contains inappropriate content.")
        }

        var design = CreatureDesign(
            creatorName: creatorName,
            name: nameCheck.filtered,
            mythology: mythology,
            element: element,
            rarity: rarity,
            description: descCheck.filtered
        )

        // Auto-generate an art prompt from the design
        design.artPrompt = generateArtPrompt(for: design)

        communityCreatures.append(design)
        playerDesigns.append(design)

        return SubmitResult(design: design, error: nil)
    }

    // MARK: - Voting

    func voteOnDesign(designId: UUID, voterName: String = "Player", isUpvote: Bool) {
        // Prevent duplicate votes from the same voter on the same design
        let alreadyVoted = communityVotes.contains {
            $0.designId == designId && $0.voterName == voterName
        }
        guard !alreadyVoted else { return }

        let vote = CommunityVote(
            designId: designId,
            voterName: voterName,
            isUpvote: isUpvote
        )
        communityVotes.append(vote)

        // Update vote count on the design
        if let index = communityCreatures.firstIndex(where: { $0.id == designId }) {
            communityCreatures[index].voteCount += isUpvote ? 1 : -1
        }
    }

    // MARK: - Art Prompt Generation

    /// Generates a DALL-E style prompt from a creature design's attributes.
    func generateArtPrompt(for design: CreatureDesign) -> String {
        let mythStyle = mythologyArtStyle(design.mythology)
        let elementVisual = elementVisualDescription(design.element)
        let rarityAura = rarityAuraDescription(design.rarity)

        return "A \(rarityAura) mythological creature named \(design.name), " +
               "inspired by \(design.mythology.rawValue) mythology. " +
               "\(design.description) " +
               "Art style: \(mythStyle). " +
               "The creature radiates \(elementVisual) energy. " +
               "Highly detailed fantasy illustration, dynamic pose, " +
               "glowing magical effects, dark atmospheric background, " +
               "concept art quality, 4K."
    }

    // MARK: - Art Style Helpers

    private func mythologyArtStyle(_ mythology: Mythology) -> String {
        switch mythology {
        case .norse: return "Viking-era runic carvings, cold blue tones, frost and steel"
        case .greek: return "Classical marble sculpture aesthetic, golden laurels, Mediterranean warmth"
        case .egyptian: return "Ancient hieroglyphic style, gold and lapis lazuli, desert sands"
        case .japanese: return "Ukiyo-e woodblock print style, ink wash painting, cherry blossoms"
        case .celtic: return "Illuminated manuscript style, knotwork patterns, emerald greens"
        case .hindu: return "Mughal miniature painting style, vibrant colors, ornate jewelry"
        case .aztec: return "Mesoamerican stone relief style, obsidian and jade, feathered serpent motifs"
        case .slavic: return "Eastern European folk art, dark forests, painted lacquer style"
        case .chinese: return "Traditional ink painting, dragon scales, jade and vermillion"
        case .african: return "Tribal mask aesthetic, bold geometric patterns, earthy tones and gold"
        }
    }

    private func elementVisualDescription(_ element: Element) -> String {
        switch element {
        case .fire: return "blazing flames and smoldering embers"
        case .water: return "flowing ocean currents and misty spray"
        case .earth: return "crumbling stone and crystalline minerals"
        case .air, .wind: return "swirling gusts and ethereal wisps"
        case .lightning: return "crackling electricity and plasma arcs"
        case .shadow: return "dark tendrils and void-like darkness"
        case .light: return "radiant golden beams and prismatic halos"
        case .nature: return "verdant vines and bioluminescent flora"
        case .frost, .ice: return "jagged ice crystals and frozen mist"
        case .arcane, .void: return "arcane sigils and dimensional rifts"
        }
    }

    private func rarityAuraDescription(_ rarity: Rarity) -> String {
        switch rarity {
        case .common: return "humble and unassuming"
        case .uncommon: return "subtly glowing"
        case .rare: return "distinctly powerful"
        case .epic: return "intensely radiant"
        case .legendary: return "overwhelmingly majestic"
        case .mythic: return "reality-bending, godlike"
        }
    }

    // MARK: - Sample Community Designs

    private func loadSampleDesigns() {
        let samples: [CreatureDesign] = [
            CreatureDesign(
                creatorName: "RuneMaster42",
                name: "Fenrishadow",
                mythology: .norse,
                element: .shadow,
                rarity: .epic,
                description: "A spectral wolf born from Fenrir's shadow, prowling between Midgard and Niflheim. Its howl silences all light.",
                voteCount: 847,
                isApproved: true,
                submittedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
            ),
            CreatureDesign(
                creatorName: "OlympusRider",
                name: "Pyraclops",
                mythology: .greek,
                element: .fire,
                rarity: .rare,
                description: "A one-eyed serpent forged in Hephaestus's volcano, its body of molten bronze never cools.",
                voteCount: 623,
                isApproved: true,
                submittedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
            ),
            CreatureDesign(
                creatorName: "AnubisFan",
                name: "Scarab Eternal",
                mythology: .egyptian,
                element: .light,
                rarity: .legendary,
                description: "A colossal scarab beetle encrusted with the Eye of Ra, rolling a miniature sun across the dunes.",
                voteCount: 1204,
                isApproved: true,
                submittedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            ),
            CreatureDesign(
                creatorName: "SakuraDrifter",
                name: "Kitsune Mirage",
                mythology: .japanese,
                element: .arcane,
                rarity: .epic,
                description: "A nine-tailed fox spirit that splits into illusory copies. Each tail holds a different stolen memory.",
                voteCount: 956,
                isApproved: true,
                submittedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
            ),
            CreatureDesign(
                creatorName: "CelticWarden",
                name: "Druimoss",
                mythology: .celtic,
                element: .nature,
                rarity: .rare,
                description: "A living oak stump that wanders ancient groves. Mushrooms sprout in its footprints and songbirds nest in its branches.",
                voteCount: 512,
                isApproved: true,
                submittedAt: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
            )
        ]

        // Generate art prompts for all samples
        communityCreatures = samples.map { design in
            var d = design
            d.artPrompt = generateArtPrompt(for: d)
            return d
        }
    }
}
