import SwiftUI

// MARK: - Creature Card View
// The crown jewel. This is what players screenshot and share.
// Researched: Pokemon TCG's card frame design + Genshin's character splash art.
// Every card must feel COLLECTIBLE — rarity frames, holographic effects, dynamic art.
// Scopely's key insight: Beautiful character art = emotional attachment = spending.

struct CreatureCardView: View {
    let species: CreatureSpecies
    let creature: Creature?
    let isShiny: Bool
    var showStats: Bool = true
    var size: CardSize = .medium

    @StateObject private var ai = AIContentService.shared
    @State private var cardImage: UIImage?
    @State private var isLoadingImage = false
    @State private var holographicAngle: Double = 0
    @State private var shimmerOffset: CGFloat = -200

    enum CardSize {
        case small, medium, large

        var width: CGFloat {
            switch self {
            case .small: return 120
            case .medium: return 200
            case .large: return 320
            }
        }

        var height: CGFloat { width * 1.4 }
        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 18
            }
        }
    }

    var body: some View {
        ZStack {
            // Card frame based on rarity
            RoundedRectangle(cornerRadius: size == .small ? 8 : 16)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: size == .small ? 8 : 16)
                        .stroke(rarityBorder, lineWidth: size == .small ? 1 : 2)
                )

            VStack(spacing: 0) {
                // Card Art Area
                ZStack {
                    // AI Generated Art or Placeholder
                    if let img = cardImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size.width - 8, height: size.height * 0.6)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: size == .small ? 6 : 12))
                    } else {
                        // Stylish placeholder
                        ZStack {
                            LinearGradient(
                                colors: [species.element.color.opacity(0.4), species.mythology.color.opacity(0.3), .black.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )

                            VStack(spacing: 6) {
                                Image(systemName: species.element.icon)
                                    .font(.system(size: size.width * 0.25))
                                    .foregroundStyle(
                                        LinearGradient(colors: [species.element.color, .white], startPoint: .top, endPoint: .bottom)
                                    )
                                    .shadow(color: species.element.color, radius: 10)

                                if isLoadingImage {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.7)
                                }
                            }
                        }
                        .frame(width: size.width - 8, height: size.height * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: size == .small ? 6 : 12))
                    }

                    // Shiny holographic overlay
                    if isShiny {
                        RoundedRectangle(cornerRadius: size == .small ? 6 : 12)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .yellow.opacity(0.2), .pink.opacity(0.15), .cyan.opacity(0.2), .clear],
                                    startPoint: UnitPoint(x: shimmerOffset / size.width, y: 0),
                                    endPoint: UnitPoint(x: (shimmerOffset + 100) / size.width, y: 1)
                                )
                            )
                            .frame(width: size.width - 8, height: size.height * 0.6)
                            .onAppear {
                                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                                    shimmerOffset = size.width + 200
                                }
                            }
                    }

                    // Rarity stars (top right)
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 1) {
                                ForEach(0..<species.rarity.starCount, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: size.fontSize * 0.6))
                                        .foregroundStyle(species.rarity.color)
                                }
                            }
                            .padding(4)
                            .background(.black.opacity(0.5), in: Capsule())
                        }
                        Spacer()
                    }
                    .padding(6)
                }

                // Card Info Area
                VStack(spacing: size == .small ? 2 : 6) {
                    // Name
                    Text(creature?.displayName ?? species.name)
                        .font(.system(size: size.fontSize, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if size != .small {
                        // Element + Mythology
                        HStack(spacing: 6) {
                            Label(species.element.rawValue.capitalized, systemImage: species.element.icon)
                                .font(.system(size: size.fontSize * 0.65, weight: .semibold))
                                .foregroundStyle(species.element.color)

                            Text("|")
                                .foregroundStyle(.white.opacity(0.3))

                            Text(species.mythology.rawValue)
                                .font(.system(size: size.fontSize * 0.65, weight: .medium))
                                .foregroundStyle(species.mythology.color)
                        }
                    }

                    if showStats, let creature = creature, size != .small {
                        // Stats bar
                        HStack(spacing: size == .large ? 12 : 6) {
                            StatPill(label: "CP", value: "\(creature.combatPower)", color: .yellow, fontSize: size.fontSize * 0.6)
                            StatPill(label: "LV", value: "\(creature.level)", color: .cyan, fontSize: size.fontSize * 0.6)
                            if size == .large {
                                StatPill(label: "HP", value: "\(creature.maxHP)", color: .green, fontSize: size.fontSize * 0.6)
                                StatPill(label: "ATK", value: "\(creature.attack)", color: .red, fontSize: size.fontSize * 0.6)
                            }
                        }
                    }
                }
                .padding(.horizontal, size == .small ? 4 : 8)
                .padding(.vertical, size == .small ? 4 : 8)
            }
            .padding(4)
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: species.rarity.color.opacity(species.rarity >= .epic ? 0.5 : 0.2), radius: species.rarity >= .legendary ? 15 : 8)
        .task {
            await loadCardImage()
        }
    }

    // MARK: - Card Styling

    private var cardBackground: LinearGradient {
        let baseColor = species.rarity.color
        return LinearGradient(
            colors: [
                Color.black.opacity(0.9),
                baseColor.opacity(0.15),
                Color.black.opacity(0.95)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var rarityBorder: LinearGradient {
        let color = species.rarity.color
        switch species.rarity {
        case .mythic:
            return LinearGradient(colors: [.red, .orange, .yellow, .pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .legendary:
            return LinearGradient(colors: [.orange, .yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .epic:
            return LinearGradient(colors: [.purple, .pink, .purple], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [color.opacity(0.5), color.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Image Loading

    private func loadCardImage() async {
        // Try cache first
        if let cached = ai.getCachedImage(for: species.id, shiny: isShiny) {
            cardImage = cached
            return
        }

        // Generate with AI
        guard ai.hasAPIKey else { return }

        await MainActor.run { isLoadingImage = true }
        let img = await ai.generateCreatureCard(species: species, isShiny: isShiny)
        await MainActor.run {
            cardImage = img
            isLoadingImage = false
        }
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let label: String
    let value: String
    let color: Color
    var fontSize: CGFloat = 9

    var body: some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: fontSize * 0.8, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
            Text(value)
                .font(.system(size: fontSize, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Creature Card Grid Item (for collection view)
struct CreatureCardGridItem: View {
    let species: CreatureSpecies
    let creature: Creature?
    let isShiny: Bool

    var body: some View {
        CreatureCardView(
            species: species,
            creature: creature,
            isShiny: isShiny,
            showStats: true,
            size: .small
        )
    }
}
