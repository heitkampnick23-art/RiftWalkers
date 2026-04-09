import SwiftUI

// MARK: - Social Hub View
// Researched: Clash Royale clan system + Discord community.
// Social bonds = #1 long-term retention driver (Supercell data).
// Players who join a guild within 7 days have 3x retention at D30.

struct SocialView: View {
    @StateObject private var guildMgr = GuildManager.shared
    @StateObject private var moderation = ContentModerationService.shared
    @State private var selectedTab: SocialTab = .guild
    @State private var showCreateGuild = false
    @State private var showAddFriend = false
    @State private var friendCode = ""
    @State private var joinedGuildID: String?
    @State private var showGuildJoinedAlert = false
    @State private var joinedGuildName = ""
    @State private var guildNameInput = ""
    @State private var guildTagInput = ""
    @State private var selectedFaction: Faction = .phantoms
    @State private var showReportSheet = false
    @State private var reportTargetName = ""

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
            .alert("Joined Guild!", isPresented: $showGuildJoinedAlert) {
                Button("OK") {}
            } message: {
                Text("You are now a member of \(joinedGuildName)!")
            }
            .sheet(isPresented: $showCreateGuild) {
                createGuildSheet
            }
            .sheet(isPresented: $showAddFriend) {
                addFriendSheet
            }
            .sheet(isPresented: $showReportSheet) {
                ReportContentView(
                    contentType: .username,
                    contentId: reportTargetName,
                    userId: reportTargetName,
                    userName: reportTargetName,
                    onDismiss: { showReportSheet = false }
                )
            }
        }
    }

    // MARK: - Create Guild Sheet

    private var createGuildSheet: some View {
        NavigationStack {
            Form {
                Section("Guild Info") {
                    TextField("Guild Name", text: $guildNameInput)
                    TextField("Tag (3 letters)", text: $guildTagInput)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: guildTagInput) { _, val in
                            if val.count > 3 { guildTagInput = String(val.prefix(3)) }
                        }
                }
                Section("Faction") {
                    Picker("Faction", selection: $selectedFaction) {
                        ForEach(Faction.allCases, id: \.self) { faction in
                            Label(faction.rawValue, systemImage: faction.icon)
                                .tag(faction)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    HStack {
                        Text("Creation Cost")
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "dollarsign.circle.fill").foregroundStyle(.yellow)
                            Text("1000 Gold")
                        }
                        .font(.caption.weight(.bold))
                    }
                }
            }
            .navigationTitle("Create Guild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCreateGuild = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if guildMgr.createGuild(name: guildNameInput, tag: guildTagInput, faction: selectedFaction) {
                            joinedGuildName = guildNameInput
                            showCreateGuild = false
                            showGuildJoinedAlert = true
                            guildNameInput = ""
                            guildTagInput = ""
                        } else {
                            HapticsService.shared.notification(.error)
                        }
                    }
                    .disabled(guildNameInput.isEmpty || guildTagInput.count < 2)
                }
            }
        }
    }

    // MARK: - Add Friend Sheet

    private var addFriendSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Your Friend Code")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("RW-\(String(UUID().uuidString.prefix(8)).uppercased())")
                        .font(.title2.weight(.black).monospaced())
                        .foregroundStyle(.cyan)
                    Button("Copy Code") {
                        UIPasteboard.general.string = "RW-\(String(UUID().uuidString.prefix(8)).uppercased())"
                        HapticsService.shared.notification(.success)
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    Text("Enter Friend Code")
                        .font(.subheadline.weight(.semibold))
                    TextField("RW-XXXXXXXX", text: $friendCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                    Button(action: {
                        HapticsService.shared.notification(.success)
                        friendCode = ""
                        showAddFriend = false
                    }) {
                        Text("Send Request")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(friendCode.count < 4)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showAddFriend = false }
                }
            }
        }
    }

    // MARK: - Guild Tab

    private var guildTab: some View {
        Group {
            if guildMgr.isInGuild {
                GuildDetailView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
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

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Top Guilds")
                                .font(.headline.weight(.bold))
                                .padding(.horizontal)

                            ForEach(demoGuilds) { guild in
                                GuildListRow(guild: guild) {
                                    guildMgr.joinGuild(guild)
                                    joinedGuildName = guild.name
                                    showGuildJoinedAlert = true
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
    }

    // MARK: - Friends Tab

    private var friendsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add friend
                Button(action: { showAddFriend = true }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(.blue)
                        Text("Add Friend")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

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
                    let name = demoNames[rank % demoNames.count]
                    LeaderboardRow(
                        rank: rank + 1,
                        name: name,
                        score: max(1000, 15000 - rank * 1200 + Int.random(in: -200...200)),
                        faction: Faction.allCases[rank % 3]
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            reportTargetName = name
                            showReportSheet = true
                        } label: {
                            Label("Report Player", systemImage: "exclamationmark.triangle")
                        }
                        Button(role: .destructive) {
                            moderation.blockUser(name)
                            HapticsService.shared.notification(.warning)
                        } label: {
                            Label("Block Player", systemImage: "hand.raised.fill")
                        }
                    }
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
            Guild(id: "guild-1", name: "Shadow Reapers", tag: "SHD", faction: .phantoms, leaderID: "leader-1", officerIDs: [], memberIDs: Array(repeating: "member", count: 28), level: 12, totalXP: 45200, territoriesControlled: 8, description: "Top PvP guild", isRecruiting: true, maxMembers: 30, createdDate: Date()),
            Guild(id: "guild-2", name: "Aether Knights", tag: "AKN", faction: .asgardians, leaderID: "leader-2", officerIDs: [], memberIDs: Array(repeating: "member", count: 25), level: 10, totalXP: 38900, territoriesControlled: 12, description: "Protecting the realm", isRecruiting: true, maxMembers: 30, createdDate: Date()),
            Guild(id: "guild-3", name: "Nexus Collective", tag: "NXC", faction: .olympians, leaderID: "leader-3", officerIDs: [], memberIDs: Array(repeating: "member", count: 22), level: 8, totalXP: 31500, territoriesControlled: 6, description: "Balance in all things", isRecruiting: true, maxMembers: 30, createdDate: Date()),
        ]
    }

    private var demoNames: [String] {
        ["RiftHunter", "MythSlayer99", "NorseLegend", "ShadowWalker", "AetherQueen", "DragonBorn", "CelticStorm", "PhoenixRise", "VoidMaster", "OdinSon"]
    }
}

// MARK: - Sub-components

struct GuildListRow: View {
    let guild: Guild
    var onJoin: (() -> Void)?

    @State private var joined = false

    var body: some View {
        HStack(spacing: 12) {
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

            Button(joined ? "Joined" : "Join") {
                if !joined {
                    joined = true
                    HapticsService.shared.notification(.success)
                    AudioService.shared.playSFX(.territoryCapture)
                    onJoin?()
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(joined ? .green : .blue, in: Capsule())
            .animation(.spring(), value: joined)
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
