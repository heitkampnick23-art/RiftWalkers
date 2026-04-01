import SwiftUI

// MARK: - Social Hub View
// Researched: Clash Royale clan system + Discord community.
// Social bonds = #1 long-term retention driver (Supercell data).
// Players who join a guild within 7 days have 3x retention at D30.

struct SocialView: View {
    @State private var selectedTab: SocialTab = .guild
    @State private var showCreateGuild = false

    enum SocialTab: String, CaseIterable {
        case guild = "Guild"
        case friends = "Friends"
        case leaderboard = "Rankings"
        case trade = "Trade"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                HStack(spacing: 0) {
                    ForEach(SocialTab.allCases, id: \.self) { tab in
                        Button(action: { withAnimation { selectedTab = tab } }) {
                            VStack(spacing: 4) {
                                Image(systemName: tabIcon(tab))
                                    .font(.system(size: 16))
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(.ultraThinMaterial)

                switch selectedTab {
                case .guild: guildTab
                case .friends: friendsTab
                case .leaderboard: leaderboardTab
                case .trade: tradeTab
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Guild Tab

    private var guildTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // No guild state
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                        )

                    Text("Join a Guild")
                        .font(.title2.weight(.bold))

                    Text("Team up with other Rift Walkers to claim territories, raid dungeons, and climb the leaderboards together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button(action: {}) {
                            Label("Browse Guilds", systemImage: "magnifyingglass")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: { showCreateGuild = true }) {
                            Label("Create", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(24)

                // Featured guilds
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Guilds")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal)

                    ForEach(demoGuilds) { guild in
                        GuildListRow(guild: guild)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Friends Tab

    private var friendsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add friend
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.blue)
                    Text("Add Friend")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Friend list placeholder
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No friends yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Share your friend code or find players near you!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            }
            .padding()
        }
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Leaderboard type selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LeaderboardType.allCases, id: \.self) { type in
                            Text(type.rawValue.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.2), in: Capsule())
                        }
                    }
                    .padding(.horizontal)
                }

                // Demo leaderboard entries
                ForEach(0..<10, id: \.self) { rank in
                    LeaderboardRow(
                        rank: rank + 1,
                        name: demoNames[rank % demoNames.count],
                        score: max(1000, 15000 - rank * 1200 + Int.random(in: -200...200)),
                        faction: Faction.allCases[rank % 3]
                    )
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Trade Tab

    private var tradeTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Trade explanation
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text("Trading Post")
                        .font(.title3.weight(.bold))

                    Text("Trade creatures and items with nearby Rift Walkers. Both players must be within 100m of each other.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Trade rules
                    VStack(alignment: .leading, spacing: 6) {
                        TradeRule(icon: "checkmark.circle", text: "Trade creatures of any rarity")
                        TradeRule(icon: "checkmark.circle", text: "Both players must be Level 8+")
                        TradeRule(icon: "exclamationmark.triangle", text: "Legendary trades cost Rift Dust")
                        TradeRule(icon: "xmark.circle", text: "Mythic and Primordial cannot be traded")
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
        }
    }

    // MARK: - Helpers

    private func tabIcon(_ tab: SocialTab) -> String {
        switch tab {
        case .guild: return "person.3.fill"
        case .friends: return "person.2.fill"
        case .leaderboard: return "trophy.fill"
        case .trade: return "arrow.triangle.2.circlepath"
        }
    }

    private var demoGuilds: [Guild] {
        [
            Guild(id: UUID(), name: "Shadow Reapers", tag: "SHD", description: "Top PvP guild", iconURL: nil, leaderID: UUID(), officerIDs: [], memberIDs: Array(repeating: UUID(), count: 28), maxMembers: 30, level: 12, experience: 0, faction: .umbra, territoriesOwned: 8, weeklyScore: 45200, createdDate: Date(), isPublic: true, requiredLevel: 15, requiredPvPRating: 1200),
            Guild(id: UUID(), name: "Aether Knights", tag: "AKN", description: "Protecting the realm", iconURL: nil, leaderID: UUID(), officerIDs: [], memberIDs: Array(repeating: UUID(), count: 25), maxMembers: 30, level: 10, experience: 0, faction: .aether, territoriesOwned: 12, weeklyScore: 38900, createdDate: Date(), isPublic: true, requiredLevel: 10, requiredPvPRating: 1000),
            Guild(id: UUID(), name: "Nexus Collective", tag: "NXC", description: "Balance in all things", iconURL: nil, leaderID: UUID(), officerIDs: [], memberIDs: Array(repeating: UUID(), count: 22), maxMembers: 30, level: 8, experience: 0, faction: .nexus, territoriesOwned: 6, weeklyScore: 31500, createdDate: Date(), isPublic: true, requiredLevel: 5, requiredPvPRating: 800),
        ]
    }

    private var demoNames: [String] {
        ["RiftHunter", "MythSlayer99", "NorseLegend", "ShadowWalker", "AetherQueen", "DragonBorn", "CelticStorm", "PhoenixRise", "VoidMaster", "OdinSon"]
    }
}

// MARK: - Sub-components

struct GuildListRow: View {
    let guild: Guild

    var body: some View {
        HStack(spacing: 12) {
            // Guild icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(guild.faction.color)
                    .frame(width: 44, height: 44)
                Image(systemName: guild.faction.icon)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(guild.name)
                        .font(.subheadline.weight(.bold))
                    Text("[\(guild.tag)]")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Label("Lv.\(guild.level)", systemImage: "star.fill")
                    Label("\(guild.memberIDs.count)/\(guild.maxMembers)", systemImage: "person.fill")
                    Label("\(guild.territoriesOwned)", systemImage: "flag.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Join") {}
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.blue, in: Capsule())
        }
        .padding(.horizontal)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let score: Int
    let faction: Faction

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                .frame(width: 36)

            // Avatar placeholder
            Circle()
                .fill(faction.color)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: faction.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                )

            Text(name)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text("\(score)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.cyan)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct TradeRule: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(icon.contains("check") ? .green : icon.contains("x") ? .red : .orange)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}
