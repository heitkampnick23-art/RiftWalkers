import SwiftUI

struct GuildDetailView: View {
    @StateObject private var guildMgr = GuildManager.shared
    @StateObject private var moderation = ContentModerationService.shared
    @State private var selectedTab: GuildTab = .info
    @State private var chatInput = ""
    @State private var showLeaveConfirm = false
    @State private var showReportSheet = false
    @State private var reportTargetMessage: GuildChatMessage?
    @State private var reportTargetMember: GuildMember?

    enum GuildTab: String, CaseIterable {
        case info = "Info"
        case members = "Members"
        case chat = "Chat"
    }

    var body: some View {
        if let guild = guildMgr.currentGuild {
            VStack(spacing: 0) {
                // Guild header
                guildHeader(guild)

                // Tab picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(GuildTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch selectedTab {
                case .info: infoTab(guild)
                case .members: membersTab
                case .chat: chatTab
                }
            }
            .alert("Leave Guild?", isPresented: $showLeaveConfirm) {
                Button("Leave", role: .destructive) { guildMgr.leaveGuild() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will lose access to guild territories and chat.")
            }
            .sheet(isPresented: $showReportSheet) {
                if let msg = reportTargetMessage {
                    ReportContentView(
                        contentType: .chatMessage,
                        contentId: msg.id,
                        userId: msg.senderName,
                        userName: msg.senderName,
                        onDismiss: { showReportSheet = false; reportTargetMessage = nil }
                    )
                } else if let member = reportTargetMember {
                    ReportContentView(
                        contentType: .username,
                        contentId: member.id,
                        userId: member.id,
                        userName: member.name,
                        onDismiss: { showReportSheet = false; reportTargetMember = nil }
                    )
                }
            }
        }
    }

    // MARK: - Header

    private func guildHeader(_ guild: Guild) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(guild.faction.color.gradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: guild.faction.icon)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(guild.name)
                            .font(.title3.weight(.black))
                        Text("[\(guild.tag)]")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(guild.faction.color)
                    }
                    Text("Level \(guild.level) \(guild.faction.rawValue) Guild")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    if guildMgr.isLeader {
                        Button(action: {}) {
                            Label("Guild Settings", systemImage: "gearshape")
                        }
                    }
                    Button(role: .destructive, action: { showLeaveConfirm = true }) {
                        Label("Leave Guild", systemImage: "arrow.right.square")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            // XP Progress
            VStack(spacing: 4) {
                let nextLevelXP = guild.level * 5000
                let progress = Double(guild.totalXP % 5000) / Double(nextLevelXP > 0 ? 5000 : 1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.1))
                        Capsule()
                            .fill(guild.faction.color)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(guild.totalXP) / \(guild.level * 5000) Guild XP")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(guild.memberCount) Members")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [guild.faction.color.opacity(0.2), .clear],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Info Tab

    private func infoTab(_ guild: Guild) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Quick stats
                HStack(spacing: 0) {
                    guildStat(value: "\(guild.memberCount)", label: "Members", icon: "person.fill")
                    guildStat(value: "\(guild.level)", label: "Level", icon: "star.fill")
                    guildStat(value: "\(guild.territoriesControlled)", label: "Territories", icon: "flag.fill")
                    guildStat(value: "\(guild.totalXP)", label: "Total XP", icon: "bolt.fill")
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "About", icon: "text.quote")
                    Text(guild.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Your role
                HStack {
                    Image(systemName: roleIcon(guildMgr.guildRank))
                        .foregroundStyle(guildMgr.guildRank.color)
                    Text("Your Role: \(guildMgr.guildRank.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Perks
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Guild Perks", icon: "gift.fill")
                    GuildPerkRow(name: "XP Boost", value: "+\(min(guild.level * 2, 20))%", unlocked: true)
                    GuildPerkRow(name: "Territory Income", value: "+\(min(guild.level * 5, 50))%", unlocked: guild.level >= 3)
                    GuildPerkRow(name: "Extra Spawns", value: "+\(min(guild.level, 5))", unlocked: guild.level >= 5)
                    GuildPerkRow(name: "Raid Boss Access", value: "Unlocked", unlocked: guild.level >= 8)
                    GuildPerkRow(name: "Legendary Trade", value: "Unlocked", unlocked: guild.level >= 10)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Online count
                HStack {
                    Circle().fill(.green).frame(width: 8, height: 8)
                    Text("\(guildMgr.guildMembers.filter(\.isOnline).count) Online")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(guildMgr.guildMembers.count) Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                let sorted = guildMgr.guildMembers.sorted { a, b in
                    if a.role != b.role {
                        return roleOrder(a.role) < roleOrder(b.role)
                    }
                    return a.isOnline && !b.isOnline
                }

                ForEach(sorted.filter { !moderation.isBlocked($0.id) }) { member in
                    MemberRow(
                        member: member,
                        isCurrentPlayer: member.name == ProgressionManager.shared.player.displayName,
                        canManage: guildMgr.isOfficer,
                        onPromote: { guildMgr.promoteToOfficer(member.id) },
                        onKick: { guildMgr.kickMember(member.id) },
                        onReport: {
                            reportTargetMember = member
                            showReportSheet = true
                        },
                        onBlock: {
                            moderation.blockUser(member.id)
                            HapticsService.shared.notification(.warning)
                        }
                    )
                }
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Chat Tab

    private var chatTab: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if guildMgr.guildChat.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.secondary)
                                Text("No messages yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 60)
                        }

                        ForEach(guildMgr.guildChat.filter { !moderation.isBlocked($0.senderName) }) { msg in
                            ChatBubble(message: msg, isOwnMessage: msg.senderName == ProgressionManager.shared.player.displayName)
                                .id(msg.id)
                                .contextMenu {
                                    if msg.senderName != ProgressionManager.shared.player.displayName && !msg.isSystem {
                                        Button(role: .destructive) {
                                            reportTargetMessage = msg
                                            showReportSheet = true
                                        } label: {
                                            Label("Report Message", systemImage: "exclamationmark.triangle")
                                        }
                                        Button(role: .destructive) {
                                            moderation.blockUser(msg.senderName)
                                            HapticsService.shared.notification(.warning)
                                        } label: {
                                            Label("Block \(msg.senderName)", systemImage: "hand.raised.fill")
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .onChange(of: guildMgr.guildChat.count) { _, _ in
                    if let last = guildMgr.guildChat.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Chat input
            HStack(spacing: 8) {
                TextField("Message...", text: $chatInput)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Button(action: sendChat) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(chatInput.isEmpty ? Color.secondary : Color.cyan)
                }
                .disabled(chatInput.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func sendChat() {
        guard !chatInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guildMgr.sendMessage(chatInput)
        chatInput = ""
        HapticsService.shared.impact(.light)
    }

    // MARK: - Helpers

    private func guildStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.cyan)
            Text(value)
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func roleIcon(_ role: GuildRole) -> String {
        switch role {
        case .leader: return "crown.fill"
        case .officer: return "shield.fill"
        case .member: return "person.fill"
        }
    }

    private func roleOrder(_ role: GuildRole) -> Int {
        switch role {
        case .leader: return 0
        case .officer: return 1
        case .member: return 2
        }
    }
}

// MARK: - Sub-components

struct GuildPerkRow: View {
    let name: String
    let value: String
    let unlocked: Bool

    var body: some View {
        HStack {
            Image(systemName: unlocked ? "checkmark.circle.fill" : "lock.fill")
                .foregroundStyle(unlocked ? .green : .secondary)
                .font(.caption)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(unlocked ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(unlocked ? .cyan : .secondary)
        }
    }
}

struct MemberRow: View {
    let member: GuildMember
    let isCurrentPlayer: Bool
    let canManage: Bool
    var onPromote: (() -> Void)?
    var onKick: (() -> Void)?
    var onReport: (() -> Void)?
    var onBlock: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(member.role.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(member.role.color)
                    )
                Circle()
                    .fill(member.isOnline ? .green : .gray)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.black, lineWidth: 1.5))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.subheadline.weight(.semibold))
                    if isCurrentPlayer {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.cyan.opacity(0.2), in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text(member.role.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(member.role.color)
                    Text("Lv.\(member.level)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(member.weeklyXP) XP/wk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !isCurrentPlayer {
                Menu {
                    if canManage && member.role == .member {
                        Button(action: { onPromote?() }) {
                            Label("Promote to Officer", systemImage: "shield.fill")
                        }
                        Button(role: .destructive, action: { onKick?() }) {
                            Label("Kick", systemImage: "xmark.circle")
                        }
                    }
                    Button(role: .destructive, action: { onReport?() }) {
                        Label("Report Player", systemImage: "exclamationmark.triangle")
                    }
                    Button(role: .destructive, action: { onBlock?() }) {
                        Label("Block Player", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct ChatBubble: View {
    let message: GuildChatMessage
    let isOwnMessage: Bool

    var body: some View {
        if message.isSystem {
            Text(message.text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.yellow.opacity(0.1), in: Capsule())
                .frame(maxWidth: .infinity)
        } else {
            HStack {
                if isOwnMessage { Spacer(minLength: 60) }

                VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 2) {
                    if !isOwnMessage {
                        Text(message.senderName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                    }
                    Text(message.text)
                        .font(.subheadline)
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    isOwnMessage ? Color.blue.opacity(0.3) : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 14)
                )

                if !isOwnMessage { Spacer(minLength: 60) }
            }
        }
    }
}
