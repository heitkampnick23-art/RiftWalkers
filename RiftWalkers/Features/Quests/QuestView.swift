import SwiftUI

// MARK: - Quest View
// Researched: Genshin's quest journal UX. Tabs for quest types + narrative display.

struct QuestView: View {
    @StateObject private var questManager = QuestManager.shared

    @State private var selectedTab: QuestTab = .daily
    @State private var selectedQuest: Quest?

    enum QuestTab: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case story = "Story"
        case events = "Events"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(QuestTab.allCases, id: \.self) { tab in
                            QuestTabButton(
                                title: tab.rawValue,
                                count: questCount(for: tab),
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation { selectedTab = tab }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Quest list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if selectedTab == .story {
                            NavigationLink(destination: StoryView()) {
                                HStack(spacing: 14) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.title2)
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Story Campaign")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text("Play through the Rift Walkers narrative")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(14)
                                .background(
                                    LinearGradient(colors: [.orange.opacity(0.2), .purple.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
                                    in: RoundedRectangle(cornerRadius: 14)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.orange.opacity(0.4), lineWidth: 1))
                            }
                        }

                        ForEach(questsForTab) { quest in
                            QuestCard(quest: quest) {
                                selectedQuest = quest
                            }
                        }

                        if questsForTab.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "scroll")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("No \(selectedTab.rawValue.lowercased()) quests available")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Quests")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedQuest) { quest in
                QuestDetailView(quest: quest)
            }
        }
    }

    private var questsForTab: [Quest] {
        switch selectedTab {
        case .daily: return questManager.dailyQuests
        case .weekly: return questManager.weeklyQuests
        case .story: return questManager.storyQuests.filter { $0.isActive }
        case .events: return questManager.eventQuests
        }
    }

    private func questCount(for tab: QuestTab) -> Int {
        switch tab {
        case .daily: return questManager.dailyQuests.filter { !$0.isCompleted }.count
        case .weekly: return questManager.weeklyQuests.filter { !$0.isCompleted }.count
        case .story: return questManager.storyQuests.filter { $0.isActive && !$0.isCompleted }.count
        case .events: return questManager.eventQuests.filter { !$0.isCompleted }.count
        }
    }
}

struct QuestTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? .blue.opacity(0.3) : .clear, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? .blue : .clear, lineWidth: 1))
        }
    }
}

// MARK: - Quest Card

struct QuestCard: View {
    let quest: Quest
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Quest type badge
                    Text(quest.type.rawValue.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(questTypeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(questTypeColor.opacity(0.2), in: Capsule())

                    if let mythology = quest.mythology {
                        HStack(spacing: 3) {
                            Image(systemName: mythology.icon)
                            Text(mythology.rawValue)
                        }
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(mythology.color)
                    }

                    Spacer()

                    if quest.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let expires = quest.expiresAt {
                        Text(timeUntil(expires))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }

                Text(quest.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(quest.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Objectives progress
                ForEach(quest.objectives) { obj in
                    HStack(spacing: 6) {
                        Image(systemName: obj.isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                            .foregroundStyle(obj.isComplete ? .green : .secondary)

                        Text(obj.description)
                            .font(.caption)
                            .foregroundStyle(obj.isComplete ? .secondary : .primary)
                            .strikethrough(obj.isComplete)

                        Spacer()

                        Text("\(obj.currentProgress)/\(obj.targetProgress)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(obj.isComplete ? .green : .secondary)
                    }
                }

                // Rewards preview
                HStack(spacing: 10) {
                    if quest.rewards.xp > 0 {
                        Label("\(quest.rewards.xp)", systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                    if quest.rewards.stardust > 0 {
                        Label("\(quest.rewards.stardust)", systemImage: "dollarsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    if quest.rewards.mythosTokens > 0 {
                        Label("\(quest.rewards.mythosTokens)", systemImage: "diamond.fill")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .opacity(quest.isCompleted ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    private var questTypeColor: Color {
        switch quest.type {
        case .daily: return .blue
        case .weekly: return .purple
        case .story: return .orange
        case .mythology: return quest.mythology?.color ?? .cyan
        case .event: return .red
        case .achievement: return .yellow
        case .territory: return .green
        case .social: return .pink
        case .battlePass: return .indigo
        }
    }

    private func timeUntil(_ date: Date) -> String {
        let remaining = date.timeIntervalSince(Date())
        if remaining < 3600 {
            return "\(Int(remaining / 60))m"
        } else if remaining < 86400 {
            return "\(Int(remaining / 3600))h"
        } else {
            return "\(Int(remaining / 86400))d"
        }
    }
}

// MARK: - Quest Detail View

struct QuestDetailView: View {
    let quest: Quest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Narrative text (for story quests)
                    if let narrative = quest.narrativeText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Story")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)

                            Text(narrative)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Objectives
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objectives")
                            .font(.headline.weight(.bold))

                        ForEach(quest.objectives) { obj in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: obj.isComplete ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(obj.isComplete ? .green : .secondary)
                                    Text(obj.description)
                                        .font(.subheadline)
                                    Spacer()
                                }

                                ProgressView(value: Double(obj.currentProgress) / Double(max(1, obj.targetProgress)))
                                    .tint(obj.isComplete ? .green : .blue)

                                Text("\(obj.currentProgress) / \(obj.targetProgress)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Rewards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Rewards")
                            .font(.headline.weight(.bold))

                        HStack(spacing: 16) {
                            if quest.rewards.xp > 0 {
                                RewardPill(icon: "star.fill", value: "\(quest.rewards.xp) XP", color: .cyan)
                            }
                            if quest.rewards.stardust > 0 {
                                RewardPill(icon: "dollarsign.circle.fill", value: "\(quest.rewards.stardust) Gold", color: .yellow)
                            }
                            if quest.rewards.mythosTokens > 0 {
                                RewardPill(icon: "diamond.fill", value: "\(quest.rewards.mythosTokens) Gems", color: .purple)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(quest.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct RewardPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// Make Quest conform to Identifiable for sheet
extension Quest: Hashable {
    static func == (lhs: Quest, rhs: Quest) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
