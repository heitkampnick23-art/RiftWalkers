import SwiftUI

struct AchievementsView: View {
    @StateObject private var manager = AchievementManager.shared
    @State private var selectedCategory: AchievementDefinition.Category = .collection

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: 16) {
                        // Progress summary
                        summaryCard

                        // Category picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(AchievementDefinition.Category.allCases) { cat in
                                    CategoryPill(
                                        category: cat,
                                        isSelected: selectedCategory == cat,
                                        count: manager.achievements(for: cat).filter { $0.1?.unlockedTier ?? 0 > 0 }.count,
                                        total: manager.achievements(for: cat).count
                                    )
                                    .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedCategory = cat } }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Achievement list
                        let items = manager.achievements(for: selectedCategory)
                        ForEach(items, id: \.0.id) { def, tracked in
                            AchievementRow(definition: def, tracked: tracked)
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 80)
                    }
                    .padding(.top, 8)
                }

                // Unlock toast
                if let unlock = manager.recentUnlock,
                   let def = manager.definition(for: unlock.definitionId) {
                    AchievementToast(definition: def, tier: unlock.unlockedTier)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(100)
                }
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .animation(.spring(response: 0.4), value: manager.recentUnlock?.definitionId)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(manager.totalTiersUnlocked)")
                    .font(.title.weight(.black))
                    .foregroundStyle(.cyan)
                Text("Unlocked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(spacing: 4) {
                Text("\(manager.totalPossible)")
                    .font(.title.weight(.black))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 30)

            VStack(spacing: 4) {
                let pct = manager.totalPossible > 0
                    ? Int(Double(manager.totalTiersUnlocked) / Double(manager.totalPossible) * 100)
                    : 0
                Text("\(pct)%")
                    .font(.title.weight(.black))
                    .foregroundStyle(.yellow)
                Text("Complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: AchievementDefinition.Category
    let isSelected: Bool
    let count: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.icon)
                .font(.caption)
            Text(category.rawValue)
                .font(.caption.weight(.semibold))
            Text("\(count)/\(total)")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .foregroundStyle(isSelected ? .white : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isSelected ? category.color.opacity(0.3) : Color.white.opacity(0.05),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(isSelected ? category.color : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let definition: AchievementDefinition
    let tracked: TrackedAchievement?

    @State private var isExpanded = false

    private var currentTier: Int { tracked?.unlockedTier ?? 0 }
    private var currentValue: Int { tracked?.currentValue ?? 0 }
    private var isUnlocked: Bool { currentTier > 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Icon with tier ring
                ZStack {
                    Circle()
                        .fill(isUnlocked ? definition.category.color.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)

                    if isUnlocked {
                        Circle()
                            .strokeBorder(definition.category.color, lineWidth: 2)
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: definition.icon)
                        .font(.title3)
                        .foregroundStyle(isUnlocked ? definition.category.color : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(definition.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(isUnlocked ? .white : .secondary)

                        // Tier badges
                        ForEach(definition.tiers, id: \.tier) { tier in
                            Image(systemName: tier.tier <= currentTier ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundStyle(tier.tier <= currentTier ? tierColor(tier.tier) : .secondary.opacity(0.4))
                        }
                    }

                    Text(definition.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Progress bar to next tier
                    if let nextTier = definition.nextTier(after: currentTier) {
                        HStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.1))
                                    Capsule()
                                        .fill(definition.category.color)
                                        .frame(width: geo.size.width * progress(to: nextTier))
                                }
                            }
                            .frame(height: 4)

                            Text("\(currentValue)/\(nextTier.requirement)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else if isUnlocked {
                        Text("MAX")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer()

                // Expand arrow
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }

            // Expanded tier details
            if isExpanded {
                Divider().padding(.horizontal)

                VStack(spacing: 8) {
                    ForEach(definition.tiers, id: \.tier) { tier in
                        HStack(spacing: 10) {
                            Image(systemName: tier.tier <= currentTier ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(tier.tier <= currentTier ? .green : .secondary)

                            Text("Tier \(tier.tier)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tierColor(tier.tier))
                                .frame(width: 45, alignment: .leading)

                            Text("\(tier.requirement)")
                                .font(.caption.weight(.medium))
                                .frame(width: 40, alignment: .trailing)

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.cyan)
                                Text("+\(tier.rewardXP) XP")
                                    .font(.system(size: 9))
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.yellow)
                                Text("+\(tier.rewardGold)")
                                    .font(.system(size: 9))
                            }

                            if let title = tier.rewardTitle {
                                Text(title)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(tierColor(tier.tier))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(tierColor(tier.tier).opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func progress(to tier: AchievementDefinition.Tier) -> Double {
        let prev = currentTier > 0 ? definition.tiers[currentTier - 1].requirement : 0
        let range = Double(tier.requirement - prev)
        guard range > 0 else { return 0 }
        return min(1, max(0, Double(currentValue - prev) / range))
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .brown
        case 2: return .gray
        case 3: return .yellow
        case 4: return .cyan
        default: return .white
        }
    }
}

// MARK: - Achievement Toast

struct AchievementToast: View {
    let definition: AchievementDefinition
    let tier: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: definition.icon)
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.yellow)
                Text("\(definition.name) — Tier \(tier)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [definition.category.color.opacity(0.8), .black.opacity(0.9)],
                startPoint: .leading, endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.yellow.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .yellow.opacity(0.3), radius: 10, y: 5)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
