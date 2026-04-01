import SwiftUI
import StoreKit

// MARK: - Shop View
// Researched: Genshin Impact's shop UX. Multiple tabs prevent overwhelm.
// Key monetization insight: Show VALUE not PRICE. "500 gems = 10 pulls"
// Fortnite's daily rotating shop creates urgency + collectibility.

struct ShopView: View {
    @StateObject private var economy = EconomyManager.shared

    @State private var selectedTab: ShopTab = .featured
    @State private var showPurchaseConfirm = false
    @State private var selectedProduct: Product?

    enum ShopTab: String, CaseIterable {
        case featured = "Featured"
        case gems = "Rift Gems"
        case items = "Items"
        case battlePass = "Battle Pass"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Currency bar
                HStack(spacing: 16) {
                    CurrencyPill(icon: "dollarsign.circle.fill", value: economy.gold, color: .yellow)
                    CurrencyPill(icon: "diamond.fill", value: economy.riftGems, color: .purple)
                    CurrencyPill(icon: "sparkle", value: economy.riftDust, color: .cyan)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ShopTab.allCases, id: \.self) { tab in
                            Button(action: { withAnimation { selectedTab = tab } }) {
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(selectedTab == tab ? .bold : .medium))
                                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? .blue.opacity(0.3) : .clear, in: Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }

                ScrollView {
                    switch selectedTab {
                    case .featured: featuredTab
                    case .gems: gemsTab
                    case .items: itemsTab
                    case .battlePass: battlePassTab
                    }
                }
            }
            .navigationTitle("Shop")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Featured Tab

    private var featuredTab: some View {
        VStack(spacing: 16) {
            // Daily deal banner
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red, .purple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                VStack(spacing: 8) {
                    Text("DAILY DEAL")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Starter Adventurer Pack")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("300 Gems + 5000 Gold + 10 Great Spheres")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                    HStack(spacing: 4) {
                        Text("$4.99")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                        Text("$9.99")
                            .font(.caption)
                            .strikethrough()
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal)

            // Rotating daily items
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Daily Rotation")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Resets in 14h 32m")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(economy.shopItems.prefix(6), id: \.id) { item in
                            ShopItemCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Gacha banner
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Mythic Summon")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("Pity: \(economy.currentPityCount)/90")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple, .black],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 120)

                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Norse Legends Banner")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Featured: Fenrir, Valkyrie Shade")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Rate Up: 0.6% -> Soft Pity at 75")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        Spacer()

                        VStack(spacing: 6) {
                            Button(action: {}) {
                                Text("1x Pull")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.purple, in: Capsule())
                            }
                            Text("160 Gems")
                                .font(.system(size: 9))
                                .foregroundStyle(.purple)

                            Button(action: {}) {
                                Text("10x Pull")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        LinearGradient(colors: [.purple, .orange], startPoint: .leading, endPoint: .trailing),
                                        in: Capsule()
                                    )
                            }
                            Text("1440 Gems (10% off)")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Gems Tab (IAP)

    private var gemsTab: some View {
        VStack(spacing: 12) {
            ForEach(economy.availableProducts, id: \.id) { product in
                GemPackCard(product: product) {
                    selectedProduct = product
                    Task {
                        _ = try? await economy.purchase(product)
                    }
                }
            }

            // Fallback if products haven't loaded
            if economy.availableProducts.isEmpty {
                ForEach(gemPackFallback, id: \.name) { pack in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pack.name)
                                .font(.subheadline.weight(.bold))
                            Text("\(pack.gems) Rift Gems")
                                .font(.caption)
                                .foregroundStyle(.purple)
                            if let bonus = pack.bonus {
                                Text("+\(bonus) Bonus!")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        Button(pack.price) {}
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.blue, in: Capsule())
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Button("Restore Purchases") {
                Task { await economy.restorePurchases() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Items Tab

    private var itemsTab: some View {
        VStack(spacing: 12) {
            ForEach(EconomyManager.ShopCategory.allCases, id: \.self) { category in
                let items = economy.shopItems.filter { $0.category == category }
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.rawValue)
                            .font(.headline.weight(.bold))
                            .padding(.horizontal)

                        ForEach(items, id: \.id) { item in
                            HStack {
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundStyle(.cyan)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let gold = item.goldCost {
                                    Button(action: {}) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "dollarsign.circle.fill")
                                                .foregroundStyle(.yellow)
                                            Text("\(gold)")
                                                .font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.yellow.opacity(0.15), in: Capsule())
                                    }
                                } else if let gems = item.gemCost {
                                    Button(action: {}) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "diamond.fill")
                                                .foregroundStyle(.purple)
                                            Text("\(gems)")
                                                .font(.caption.weight(.bold))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.purple.opacity(0.15), in: Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .padding(.vertical)
    }

    // MARK: - Battle Pass Tab

    private var battlePassTab: some View {
        VStack(spacing: 16) {
            // Season banner
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Mythology.norse.color, .black],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 100)

                VStack(spacing: 4) {
                    Text("SEASON 1")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Whispers of Ragnarok")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                    Text("42 days remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal)

            // Current tier
            HStack {
                Text("Current Tier:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Tier \(ProgressionManager.shared.player.battlePassTier)")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if !ProgressionManager.shared.player.battlePassPremium {
                    Button(action: {}) {
                        Text("Upgrade to Premium")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing),
                                in: Capsule()
                            )
                    }
                }
            }
            .padding(.horizontal)

            // Tier reward preview
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1..<16, id: \.self) { tier in
                        BattlePassTierCard(
                            tier: tier,
                            isUnlocked: tier <= ProgressionManager.shared.player.battlePassTier,
                            isPremium: false
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Fallback gem packs

    private var gemPackFallback: [(name: String, gems: Int, bonus: Int?, price: String)] {
        [
            ("Handful of Gems", 100, nil, "$0.99"),
            ("Pouch of Gems", 500, 50, "$4.99"),
            ("Chest of Gems", 1200, 200, "$9.99"),
            ("Vault of Gems", 2500, 500, "$19.99"),
            ("Hoard of Gems", 6500, 1500, "$49.99"),
        ]
    }
}

// MARK: - Components

struct CurrencyPill: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct ShopItemCard: View {
    let item: EconomyManager.ShopItem

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 50, height: 50)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

            Text(item.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)

            if let gold = item.goldCost {
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.yellow)
                    Text("\(gold)")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .frame(width: 80)
    }
}

struct GemPackCard: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "diamond.fill")
                .font(.title2)
                .foregroundStyle(.purple)

            VStack(alignment: .leading) {
                Text(product.displayName)
                    .font(.subheadline.weight(.bold))
                Text(product.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: action) {
                Text(product.displayPrice)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct BattlePassTierCard: View {
    let tier: Int
    let isUnlocked: Bool
    let isPremium: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("T\(tier)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 8)
                .fill(isUnlocked ? .green.opacity(0.3) : .gray.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: rewardIcon(tier))
                        .font(.title3)
                        .foregroundStyle(isUnlocked ? .white : .secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isUnlocked ? .green : .gray.opacity(0.3), lineWidth: 1)
                )

            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }
        }
    }

    private func rewardIcon(_ tier: Int) -> String {
        switch tier % 5 {
        case 0: return "diamond.fill"
        case 1: return "circle.fill"
        case 2: return "dollarsign.circle.fill"
        case 3: return "star.fill"
        default: return "gift.fill"
        }
    }
}
