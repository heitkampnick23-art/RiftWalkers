import SwiftUI

// MARK: - Profile View
// Researched: Pokemon GO profile = ego & identity. Players NEED to show off.
// Achievement walls, rare creature showcases, faction pride badges.

struct ProfileView: View {
    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var economy = EconomyManager.shared

    @State private var selectedSection: ProfileSection = .stats
    @State private var showSettings = false

    enum ProfileSection: String, CaseIterable {
        case stats = "Stats"
        case achievements = "Achievements"
        case collection = "Collection"
    }

    var player: Player { progression.player }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Profile Header
                    ZStack(alignment: .bottomLeading) {
                        // Banner gradient
                        LinearGradient(
                            colors: [player.faction?.color ?? .indigo, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(height: 160)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .bottom, spacing: 12) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 70, height: 70)
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(.white)
                                }
                                .overlay(
                                    ZStack {
                                        Circle()
                                            .fill(.indigo)
                                            .frame(width: 24, height: 24)
                                        Text("\(player.level)")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(.white)
                                    }
                                    .offset(x: 24, y: 24)
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.displayName)
                                        .font(.title2.weight(.black))
                                        .foregroundStyle(.white)

                                    Text(player.title ?? "Rift Walker")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.7))

                                    if let faction = player.faction {
                                        HStack(spacing: 4) {
                                            Image(systemName: faction.icon)
                                            Text(faction.rawValue)
                                        }
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(faction.color)
                                    }
                                }
                            }

                            // XP bar
                            VStack(alignment: .leading, spacing: 2) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.2))
                                        Capsule()
                                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * player.levelProgress)
                                    }
                                }
                                .frame(height: 6)

                                Text("\(player.experience) / \(player.experienceToNextLevel) XP")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 0))

                    // MARK: - Quick Stats
                    HStack(spacing: 0) {
                        QuickStat(value: "\(player.creaturesCaught)", label: "Caught", icon: "pawprint.fill")
                        QuickStat(value: String(format: "%.1fkm", player.totalDistanceWalked / 1000), label: "Walked", icon: "figure.walk")
                        QuickStat(value: "\(player.pvpWins)", label: "PvP Wins", icon: "figure.fencing")
                        QuickStat(value: "\(player.territoriesClaimed)", label: "Territories", icon: "flag.fill")
                    }
                    .padding(.horizontal)

                    // Streak
                    if player.dailyStreak > 0 {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(player.dailyStreak) Day Streak")
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text("Keep it going!")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // MARK: - Section Tabs
                    Picker("Section", selection: $selectedSection) {
                        ForEach(ProfileSection.allCases, id: \.self) { section in
                            Text(section.rawValue).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch selectedSection {
                    case .stats: statsSection
                    case .achievements: achievementsSection
                    case .collection: collectionSection
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: 12) {
            // Currencies
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Currencies", icon: "banknote.fill")

                HStack(spacing: 12) {
                    CurrencyCard(icon: "dollarsign.circle.fill", name: "Gold", value: economy.gold, color: .yellow)
                    CurrencyCard(icon: "diamond.fill", name: "Gems", value: economy.riftGems, color: .purple)
                    CurrencyCard(icon: "sparkle", name: "Dust", value: economy.riftDust, color: .cyan)
                }
            }
            .padding(.horizontal)

            // Essence per mythology
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Mythic Essences", icon: "sparkles")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Mythology.allCases) { myth in
                        HStack(spacing: 6) {
                            Image(systemName: myth.icon)
                                .foregroundStyle(myth.color)
                                .frame(width: 20)
                            Text(myth.rawValue)
                                .font(.caption)
                            Spacer()
                            Text("\(economy.essences[myth] ?? 0)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(myth.color)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal)

            // Battle stats
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Battle Record", icon: "figure.fencing")

                HStack(spacing: 12) {
                    StatBox(label: "PvP Rating", value: "\(player.pvpRating)", color: .orange)
                    StatBox(label: "Wins", value: "\(player.pvpWins)", color: .green)
                    StatBox(label: "Losses", value: "\(player.pvpLosses)", color: .red)
                    StatBox(label: "Win Rate", value: player.pvpWins + player.pvpLosses > 0 ? "\(Int(Double(player.pvpWins) / Double(player.pvpWins + player.pvpLosses) * 100))%" : "—", color: .cyan)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 80)
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(spacing: 12) {
            // Summary bar
            let mgr = AchievementManager.shared
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("\(mgr.totalTiersUnlocked) / \(mgr.totalPossible) Tiers Unlocked")
                    .font(.subheadline.weight(.bold))
                Spacer()
                NavigationLink {
                    AchievementsView()
                } label: {
                    Text("View All")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            // Recent unlocks preview
            let recentUnlocks = mgr.achievements
                .filter { $0.unlockedTier > 0 }
                .sorted { ($0.unlockedDate ?? .distantPast) > ($1.unlockedDate ?? .distantPast) }
                .prefix(5)

            if recentUnlocks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No achievements yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Start exploring to unlock achievements!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
            } else {
                ForEach(Array(recentUnlocks), id: \.definitionId) { tracked in
                    if let def = mgr.definition(for: tracked.definitionId) {
                        HStack(spacing: 12) {
                            Image(systemName: def.icon)
                                .font(.title3)
                                .foregroundStyle(def.category.color)
                                .frame(width: 36, height: 36)
                                .background(def.category.color.opacity(0.15), in: Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(def.name)
                                        .font(.subheadline.weight(.bold))
                                    ForEach(1...tracked.unlockedTier, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 7))
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                Text(def.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 80)
    }

    // MARK: - Collection Section

    private var collectionSection: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(spacing: 8) {
                Text("\(player.creaturesCaught) / \(SpeciesDatabase.shared.species.count)")
                    .font(.title.weight(.black))

                ProgressView(value: progression.collectionProgress)
                    .tint(.cyan)

                Text("\(Int(progression.collectionProgress * 100))% Complete")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Per-mythology breakdown
            ForEach(Mythology.allCases) { myth in
                HStack(spacing: 10) {
                    Image(systemName: myth.icon)
                        .foregroundStyle(myth.color)
                        .frame(width: 24)

                    Text(myth.rawValue)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 70, alignment: .leading)

                    ProgressView(value: progression.mythologyProgress[myth] ?? 0)
                        .tint(myth.color)

                    Text("\(SpeciesDatabase.shared.speciesForMythology(myth).count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 80)
    }

    private func tierColor(_ tier: AchievementTier) -> Color {
        switch tier {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .platinum: return .cyan
        case .diamond: return .purple
        }
    }
}

// MARK: - Profile Components

struct QuickStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
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
}

struct CurrencyCard: View {
    let icon: String
    let name: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.subheadline.weight(.bold))
            Text(name)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("musicEnabled") private var musicEnabled = true
    @AppStorage("sfxEnabled") private var sfxEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("arEnabled") private var arEnabled = true
    @AppStorage("batterySaver") private var batterySaver = false
    @AppStorage("voiceGuideEnabled") private var voiceGuideEnabled = true

    @StateObject private var ai = AIContentService.shared
    @State private var apiKeyInput = ""
    @State private var showAPIKeySaved = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Toggle("Music", isOn: $musicEnabled)
                    Toggle("Sound Effects", isOn: $sfxEnabled)
                }

                Section("Gameplay") {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    Toggle("AR Mode", isOn: $arEnabled)
                    Toggle("Rift Guide Voice", isOn: $voiceGuideEnabled)
                    Toggle("Battery Saver", isOn: $batterySaver)
                }

                Section("Notifications") {
                    Toggle("Push Notifications", isOn: $notificationsEnabled)
                }

                Section {
                    HStack {
                        Text("AI Card Art")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(ai.isUsingCloudProxy ? "Cloud" : "Local Key")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    HStack {
                        Text("Mode")
                        Spacer()
                        Text(ai.isUsingCloudProxy ? "RiftWalkers Cloud" : "Custom API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    SecureField("Custom OpenAI Key (optional)", text: $apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    if !apiKeyInput.isEmpty {
                        Button(action: saveAPIKey) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text(showAPIKeySaved ? "Saved!" : "Use Custom Key")
                            }
                        }
                    }
                } header: {
                    Text("AI Content (DALL-E 3)")
                } footer: {
                    Text("AI creature art is powered by RiftWalkers Cloud by default. Optionally use your own OpenAI key for unlimited generation.")
                }

                Section("Account") {
                    Button("Sign Out") {}
                        .foregroundStyle(.red)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func saveAPIKey() {
        ai.setAPIKey(apiKeyInput)
        apiKeyInput = ""
        showAPIKeySaved = true
        HapticsService.shared.notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showAPIKeySaved = false
        }
    }
}
