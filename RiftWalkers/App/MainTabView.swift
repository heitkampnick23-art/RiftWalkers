import SwiftUI

// MARK: - Main Tab View
// Researched: Pokemon GO has 1 main screen (map) + side navigation.
// We use 5 tabs like most top-grossing games: Map, Creatures, Quests, Social, Profile.
// Map is default tab and always accessible. Tab bar is translucent to maximize map space.

struct MainTabView: View {
    @State private var selectedTab: Tab = .map
    @State private var showShop = false
    @State private var showDailyReward = false
    @State private var showCompanionChat = false

    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var questManager = QuestManager.shared

    enum Tab: String, CaseIterable {
        case map = "Map"
        case creatures = "Creatures"
        case quests = "Quests"
        case social = "Social"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .map: return "map.fill"
            case .creatures: return "pawprint.fill"
            case .quests: return "scroll.fill"
            case .social: return "person.3.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .map: MapView()
                case .creatures: InventoryView()
                case .quests: QuestView()
                case .social: SocialView()
                case .profile: ProfileView()
                }
            }

            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        badge: badgeCount(for: tab)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                        HapticsService.shared.selection()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                    .ignoresSafeArea()
            )

            // FABs on map
            if selectedTab == .map {
                VStack {
                    Spacer()
                    HStack {
                        // Companion chat FAB
                        Button(action: { showCompanionChat = true }) {
                            Image(systemName: "sparkle")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(colors: [.cyan, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Circle()
                                )
                                .shadow(color: .cyan.opacity(0.4), radius: 8)
                        }
                        .padding(.leading, 16)

                        Spacer()

                        // Shop FAB
                        Button(action: { showShop = true }) {
                            Image(systemName: "bag.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: Circle()
                                )
                                .shadow(color: .purple.opacity(0.4), radius: 8)
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 90)
                }
            }
        }
        .overlay { RiftGuideOverlay() }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showShop) {
            ShopView()
        }
        .sheet(isPresented: $showDailyReward) {
            DailyRewardView()
        }
        .sheet(isPresented: $showCompanionChat) {
            CompanionChatView()
        }
        .onAppear {
            checkDailyReward()
            // Trigger guide hints based on context
            if progression.player.creaturesCaught == 0 {
                AICompanionService.shared.onFirstLaunch()
            }
            AICompanionService.shared.onDailyLogin(streak: progression.player.dailyStreak)
        }
    }

    private func badgeCount(for tab: Tab) -> Int {
        switch tab {
        case .quests:
            return questManager.dailyQuests.filter { !$0.isCompleted }.count
        default:
            return 0
        }
    }

    private func checkDailyReward() {
        let lastClaim = UserDefaults.standard.double(forKey: "lastDailyRewardClaim")
        let now = Date().timeIntervalSince1970
        if now - lastClaim > 86400 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showDailyReward = true
            }
        }
    }
}

// MARK: - Custom Tab Button

struct TabButton: View {
    let tab: MainTabView.Tab
    let isSelected: Bool
    let badge: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? 22 : 18))
                        .foregroundStyle(isSelected ? .cyan : .white.opacity(0.4))

                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(.red, in: Circle())
                            .offset(x: 6, y: -4)
                    }
                }

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Daily Reward View

struct DailyRewardView: View {
    @StateObject private var economy = EconomyManager.shared
    @StateObject private var progression = ProgressionManager.shared
    @State private var claimedReward: EconomyManager.DailyReward?
    @State private var animateReward = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("DAILY REWARD")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Day \(progression.player.dailyStreak)")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .scaleEffect(animateReward ? 1 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2), value: animateReward)

                // 7-day calendar
                HStack(spacing: 8) {
                    ForEach(economy.dailyRewardSchedule, id: \.day) { reward in
                        let isToday = ((progression.player.dailyStreak - 1) % 7) + 1 == reward.day
                        let isPast = ((progression.player.dailyStreak - 1) % 7) + 1 > reward.day

                        VStack(spacing: 4) {
                            Text("Day \(reward.day)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))

                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isToday ? .yellow.opacity(0.3) : isPast ? .green.opacity(0.2) : .white.opacity(0.05))
                                    .frame(width: 40, height: 40)

                                if isPast {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.green)
                                } else if isToday {
                                    Image(systemName: "gift.fill")
                                        .foregroundStyle(.yellow)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if reward.gems > 0 {
                                Text("+\(reward.gems)💎")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }

                if let reward = claimedReward {
                    VStack(spacing: 8) {
                        Text(reward.description)
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 16) {
                            if reward.gold > 0 {
                                Label("+\(reward.gold)", systemImage: "dollarsign.circle.fill")
                                    .foregroundStyle(.yellow)
                            }
                            if reward.gems > 0 {
                                Label("+\(reward.gems)", systemImage: "diamond.fill")
                                    .foregroundStyle(.purple)
                            }
                        }
                        .font(.subheadline.weight(.bold))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: claimReward) {
                    Text(claimedReward == nil ? "Claim Reward!" : "Continue")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear { animateReward = true }
    }

    private func claimReward() {
        if claimedReward != nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastDailyRewardClaim")
            dismiss()
        } else {
            withAnimation {
                claimedReward = economy.claimDailyReward(streakDay: progression.player.dailyStreak)
            }
            HapticsService.shared.notification(.success)
            AudioService.shared.playSFX(.coinCollect)
        }
    }
}
