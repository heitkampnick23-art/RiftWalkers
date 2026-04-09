import Foundation
import SwiftUI

final class GuildManager: ObservableObject {
    static let shared = GuildManager()

    @Published var currentGuild: Guild?
    @Published var guildMembers: [GuildMember] = []
    @Published var guildChat: [GuildChatMessage] = []
    @Published var guildRank: GuildRole = .member

    private let saveKey = "riftwalkers_guild"

    private init() {
        loadGuild()
    }

    var isInGuild: Bool { currentGuild != nil }
    var isLeader: Bool { guildRank == .leader }
    var isOfficer: Bool { guildRank == .officer || guildRank == .leader }

    // MARK: - Guild Actions

    func createGuild(name: String, tag: String, faction: Faction) -> Bool {
        guard !isInGuild else { return false }
        guard ContentModerationService.shared.isContentAppropriate(name) else { return false }
        guard ContentModerationService.shared.isContentAppropriate(tag) else { return false }
        guard EconomyManager.shared.spend(gold: 1000) else { return false }

        let playerName = ProgressionManager.shared.player.displayName
        let playerId = ProgressionManager.shared.player.id.uuidString

        let guild = Guild(
            id: UUID().uuidString, name: name, tag: tag.uppercased(),
            faction: faction, leaderID: playerId, officerIDs: [],
            memberIDs: [playerId], level: 1, totalXP: 0,
            territoriesControlled: 0, description: "Founded by \(playerName)",
            isRecruiting: true, maxMembers: 30, createdDate: Date()
        )

        currentGuild = guild
        guildRank = .leader
        guildMembers = [
            GuildMember(id: playerId, name: playerName, level: ProgressionManager.shared.player.level,
                        role: .leader, joinDate: Date(), weeklyXP: 0, isOnline: true)
        ]

        // Add bot members for life
        addDemoMembers()
        saveGuild()

        AudioService.shared.playSFX(.territoryCapture)
        HapticsService.shared.notification(.success)
        return true
    }

    func joinGuild(_ guild: Guild) {
        guard !isInGuild else { return }

        let playerName = ProgressionManager.shared.player.displayName
        let playerId = ProgressionManager.shared.player.id.uuidString

        var g = guild
        g.memberIDs.append(playerId)
        currentGuild = g
        guildRank = .member

        guildMembers = generateMembersForGuild(g)
        guildMembers.append(GuildMember(
            id: playerId, name: playerName,
            level: ProgressionManager.shared.player.level,
            role: .member, joinDate: Date(), weeklyXP: 0, isOnline: true
        ))

        saveGuild()
        AudioService.shared.playSFX(.territoryCapture)
        HapticsService.shared.notification(.success)
    }

    func leaveGuild() {
        currentGuild = nil
        guildMembers = []
        guildChat = []
        guildRank = .member
        UserDefaults.standard.removeObject(forKey: saveKey)
        HapticsService.shared.notification(.warning)
    }

    func promoteToOfficer(_ memberId: String) {
        guard isLeader else { return }
        if let idx = guildMembers.firstIndex(where: { $0.id == memberId }) {
            guildMembers[idx].role = .officer
            currentGuild?.officerIDs.append(memberId)
            saveGuild()
        }
    }

    func kickMember(_ memberId: String) {
        guard isOfficer else { return }
        guildMembers.removeAll { $0.id == memberId }
        currentGuild?.memberIDs.removeAll { $0 == memberId }
        currentGuild?.officerIDs.removeAll { $0 == memberId }
        saveGuild()
    }

    func sendMessage(_ text: String) {
        // Content moderation: filter profanity before sending
        let filtered = ContentModerationService.shared.filterContent(text)
        let cleanText = filtered.filtered

        let msg = GuildChatMessage(
            id: UUID().uuidString,
            senderName: ProgressionManager.shared.player.displayName,
            text: cleanText,
            timestamp: Date(),
            isSystem: false
        )
        guildChat.append(msg)

        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...5)) { [weak self] in
            guard let self, let guild = self.currentGuild else { return }
            let names = self.guildMembers.filter { $0.isOnline && $0.name != ProgressionManager.shared.player.displayName }
            guard let responder = names.randomElement() else { return }
            let responses = [
                "Nice!", "Let's go raid later", "Anyone near the Norse territory?",
                "GG everyone", "I just evolved my Zmey!", "Need help with a rift dungeon",
                "Who's up for PvP?", "Just caught a shiny!", "Great job team",
                "How many territories do we control now?"
            ]
            let reply = GuildChatMessage(
                id: UUID().uuidString,
                senderName: responder.name,
                text: responses.randomElement()!,
                timestamp: Date(),
                isSystem: false
            )
            self.guildChat.append(reply)
        }
    }

    func contributeXP(_ amount: Int) {
        currentGuild?.totalXP += amount
        let newLevel = max(1, (currentGuild?.totalXP ?? 0) / 5000 + 1)
        if newLevel > (currentGuild?.level ?? 1) {
            currentGuild?.level = newLevel
            let msg = GuildChatMessage(
                id: UUID().uuidString,
                senderName: "System",
                text: "Guild leveled up to Level \(newLevel)!",
                timestamp: Date(),
                isSystem: true
            )
            guildChat.append(msg)
        }
        saveGuild()
    }

    // MARK: - Persistence

    private func saveGuild() {
        guard let guild = currentGuild else { return }
        let data = GuildSaveData(guild: guild, members: guildMembers, rank: guildRank)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func loadGuild() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let save = try? JSONDecoder().decode(GuildSaveData.self, from: data) else { return }
        currentGuild = save.guild
        guildMembers = save.members
        guildRank = save.rank
    }

    // MARK: - Demo Data

    private func addDemoMembers() {
        let demoNames = ["StormBreaker", "AetherWolf", "NightFury", "RiftBlade", "MythHunter",
                         "ShadowFang", "IronValor", "CelestialMage", "DragonSlayer"]
        for (i, name) in demoNames.prefix(Int.random(in: 4...8)).enumerated() {
            let member = GuildMember(
                id: UUID().uuidString, name: name,
                level: Int.random(in: 5...25),
                role: i == 0 ? .officer : .member,
                joinDate: Date().addingTimeInterval(-Double.random(in: 86400...604800)),
                weeklyXP: Int.random(in: 500...5000),
                isOnline: Bool.random()
            )
            guildMembers.append(member)
        }
    }

    private func generateMembersForGuild(_ guild: Guild) -> [GuildMember] {
        let names = ["CelticWarden", "PhoenixAsh", "VoidReaper", "RuneMaster", "ThunderGod",
                     "MysticSage", "IronFist", "NorseViking", "ShadowDancer", "AncientOne"]
        var members: [GuildMember] = []
        members.append(GuildMember(
            id: guild.leaderID, name: "\(guild.name) Leader",
            level: Int.random(in: 20...35), role: .leader,
            joinDate: guild.createdDate, weeklyXP: Int.random(in: 3000...8000), isOnline: true
        ))
        let count = min(guild.memberIDs.count, names.count)
        for i in 0..<count {
            members.append(GuildMember(
                id: UUID().uuidString, name: names[i],
                level: Int.random(in: 5...28),
                role: i < 2 ? .officer : .member,
                joinDate: Date().addingTimeInterval(-Double.random(in: 86400...1209600)),
                weeklyXP: Int.random(in: 200...6000), isOnline: Bool.random()
            ))
        }
        return members
    }
}

// MARK: - Models

enum GuildRole: String, Codable {
    case leader, officer, member

    var displayName: String {
        switch self {
        case .leader: return "Leader"
        case .officer: return "Officer"
        case .member: return "Member"
        }
    }

    var color: Color {
        switch self {
        case .leader: return .yellow
        case .officer: return .orange
        case .member: return .secondary
        }
    }
}

struct GuildMember: Identifiable, Codable {
    let id: String
    let name: String
    let level: Int
    var role: GuildRole
    let joinDate: Date
    var weeklyXP: Int
    var isOnline: Bool
}

struct GuildChatMessage: Identifiable {
    let id: String
    let senderName: String
    let text: String
    let timestamp: Date
    let isSystem: Bool
}

struct GuildSaveData: Codable {
    let guild: Guild
    let members: [GuildMember]
    let rank: GuildRole
}
