import SwiftUI

// MARK: - Onboarding View
// Cinematic onboarding → hard paywall with 1-week free trial.
// Researched: Calm, Headspace, Locket Widget — all use cinematic intros
// that build emotional value BEFORE showing price. By the time users
// see the paywall, they're already invested.
// Flow: Cinematic Intro → Lore → Features → Name → Faction → Paywall → Permissions

struct OnboardingView: View {
    @StateObject private var progression = ProgressionManager.shared

    @Binding var isOnboardingComplete: Bool

    @State private var currentPage = 0
    @State private var username = ""
    @State private var selectedFaction: Faction?
    @State private var animateIn = false
    @State private var cinematicPhase = 0
    @State private var showSkip = false
    @State private var particleOffset: CGFloat = 0

    private let totalPages = 7 // cinematic, lore, features, name, faction, paywall, permissions

    var body: some View {
        ZStack {
            // Animated background
            backgroundLayer
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 1.0), value: currentPage)

            // Floating particles
            particleLayer
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Content
            TabView(selection: $currentPage) {
                cinematicIntroPage.tag(0)
                lorePage.tag(1)
                featuresPage.tag(2)
                namePage.tag(3)
                factionPage.tag(4)
                paywallPage.tag(5)
                permissionsPage.tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.5), value: currentPage)

            // Page dots (hidden on cinematic and paywall)
            if currentPage > 0 && currentPage != 5 {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? .white : .white.opacity(0.2))
                                .frame(width: i == currentPage ? 10 : 6, height: i == currentPage ? 10 : 6)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { animateIn = true }
            startCinematicSequence()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Rift energy overlay
            if currentPage == 0 || currentPage == 5 {
                RadialGradient(
                    colors: [.purple.opacity(0.3), .clear],
                    center: .center,
                    startRadius: 50,
                    endRadius: 400
                )
                .scaleEffect(animateIn ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateIn)
            }
        }
    }

    private var backgroundColors: [Color] {
        switch currentPage {
        case 0: return [Color(red: 0.05, green: 0.02, blue: 0.15), .black]
        case 1: return [.purple.opacity(0.7), .black]
        case 2: return [.indigo, .black]
        case 3: return [.blue.opacity(0.7), .black]
        case 4: return [selectedFaction?.color ?? .cyan, .black]
        case 5: return [Color(red: 0.1, green: 0.0, blue: 0.2), .black]
        case 6: return [.green.opacity(0.6), .black]
        default: return [.black, .black]
        }
    }

    // MARK: - Floating Particles

    private var particleLayer: some View {
        GeometryReader { geo in
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(Double.random(in: 0.05...0.2)))
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat(i) / 20.0 * geo.size.height + particleOffset
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                particleOffset = -100
            }
        }
    }

    // MARK: - Page 0: Cinematic Intro

    private var cinematicIntroPage: some View {
        VStack(spacing: 0) {
            Spacer()

            // Phase-based cinematic text reveal
            VStack(spacing: 20) {
                if cinematicPhase >= 1 {
                    Text("In the beginning...")
                        .font(.title3.weight(.medium).italic())
                        .foregroundStyle(.white.opacity(0.6))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if cinematicPhase >= 2 {
                    Text("The ancient myths were real.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if cinematicPhase >= 3 {
                    VStack(spacing: 8) {
                        Text("Now the barriers between worlds")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("are shattering.")
                            .font(.title.weight(.black))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .purple, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    .transition(.opacity.combined(with: .scale))
                }

                if cinematicPhase >= 4 {
                    // Rift portal animation
                    ZStack {
                        ForEach(0..<3, id: \.self) { ring in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.cyan.opacity(0.6), .purple.opacity(0.4), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: CGFloat(80 + ring * 40), height: CGFloat(80 + ring * 40))
                                .rotationEffect(.degrees(animateIn ? Double(ring) * 120 : 0))
                                .animation(
                                    .linear(duration: Double(6 + ring * 2)).repeatForever(autoreverses: false),
                                    value: animateIn
                                )
                        }

                        Image(systemName: "hurricane")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if cinematicPhase >= 5 {
                    VStack(spacing: 8) {
                        Text("RIFT WALKERS")
                            .font(.system(size: 38, weight: .black, design: .default))
                            .tracking(4)
                            .foregroundStyle(.white)
                        Text("Walk the Myth. Capture the Legend.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                    .transition(.opacity)
                }
            }
            .multilineTextAlignment(.center)

            Spacer()

            if cinematicPhase >= 5 {
                OnboardingButton(title: "Enter the Rift") {
                    withAnimation { currentPage = 1 }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding()
    }

    private func startCinematicSequence() {
        let delays: [Double] = [0.8, 2.2, 3.8, 5.2, 6.5]
        for (i, delay) in delays.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.8)) {
                    cinematicPhase = i + 1
                }
                if i < 3 { HapticsService.shared.selection() }
                if i == 3 { HapticsService.shared.notification(.success) }
            }
        }
    }

    // MARK: - Page 1: Mythology Lore

    private var lorePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated mythology wheel
            ZStack {
                ForEach(Array(Mythology.allCases.prefix(6).enumerated()), id: \.element) { i, myth in
                    VStack(spacing: 4) {
                        Image(systemName: myth.icon)
                            .font(.title)
                            .foregroundStyle(myth.color)
                        Text(myth.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .offset(
                        x: cos(CGFloat(i) / 6.0 * .pi * 2 - .pi / 2) * 100,
                        y: sin(CGFloat(i) / 6.0 * .pi * 2 - .pi / 2) * 100
                    )
                }

                // Center glow
                Circle()
                    .fill(
                        RadialGradient(colors: [.white.opacity(0.2), .clear], center: .center, startRadius: 5, endRadius: 50)
                    )
                    .frame(width: 100, height: 100)
            }
            .frame(height: 260)

            VStack(spacing: 12) {
                Text("Six Mythologies. One World.")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                Text("Norse gods. Greek titans. Egyptian pharaohs. Japanese spirits. Celtic druids. Hindu deities. They're all here, and they're all yours to discover.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()

            OnboardingButton(title: "Continue") {
                withAnimation { currentPage = 2 }
            }
        }
        .padding()
    }

    // MARK: - Page 2: Feature Showcase

    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Your Adventure Includes")
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            VStack(spacing: 14) {
                FeatureCard(icon: "camera.viewfinder", title: "AR Encounters", description: "See creatures in your world through your camera", color: .green)
                FeatureCard(icon: "wand.and.stars", title: "AI-Generated Card Art", description: "Every creature card is uniquely crafted by AI", color: .purple)
                FeatureCard(icon: "bubble.left.and.bubble.right.fill", title: "Talk to Creatures", description: "Chat with mythic beings before you capture them", color: .blue)
                FeatureCard(icon: "speaker.wave.3.fill", title: "Voice-Guided Adventure", description: "Your Rift Guide speaks with real-time tips", color: .orange)
                FeatureCard(icon: "figure.fencing", title: "Real-Time PvP", description: "Battle other Walkers and climb the ranked ladder", color: .red)
            }
            .padding(.horizontal)

            Spacer()

            OnboardingButton(title: "Continue") {
                withAnimation { currentPage = 3 }
            }
        }
        .padding()
    }

    // MARK: - Page 3: Name

    private var namePage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "person.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Choose Your Name")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                Text("This is how other Rift Walkers will know you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            TextField("Enter your name", text: $username)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 40)

            if !username.isEmpty && username.count < 3 {
                Text("Minimum 3 characters")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            OnboardingButton(title: "Next", isEnabled: username.count >= 3) {
                progression.player.displayName = username
                withAnimation { currentPage = 4 }
            }
        }
        .padding()
    }

    // MARK: - Page 4: Faction

    private var factionPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Choose Your Allegiance")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                Text("Your faction determines your allies and territory color.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                ForEach(Faction.allCases, id: \.self) { faction in
                    Button(action: { withAnimation(.spring()) { selectedFaction = faction } }) {
                        HStack(spacing: 12) {
                            Image(systemName: faction.icon)
                                .font(.title2)
                                .foregroundStyle(faction.color)
                                .frame(width: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(faction.rawValue)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(faction.description)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(2)
                            }

                            Spacer()

                            if selectedFaction == faction {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(faction.color)
                                    .transition(.scale)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedFaction == faction ? faction.color.opacity(0.2) : .white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedFaction == faction ? faction.color : .white.opacity(0.1), lineWidth: selectedFaction == faction ? 2 : 1)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            OnboardingButton(title: "Join \(selectedFaction?.rawValue ?? "...")", isEnabled: selectedFaction != nil) {
                progression.player.faction = selectedFaction
                withAnimation { currentPage = 5 }
            }
        }
        .padding()
    }

    // MARK: - Page 5: HARD PAYWALL (1-Week Free Trial)
    // Researched: Calm does $200M/year with this exact pattern.
    // Show value → build emotion → present trial → convert.

    private var paywallPage: some View {
        VStack(spacing: 0) {
            // Close / Restore
            HStack {
                Spacer()
                Button("Restore") {
                    Task { await EconomyManager.shared.restorePurchases() }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            // Crown / Premium Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow.opacity(0.3), .orange.opacity(0.1), .clear],
                            center: .center, startRadius: 20, endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                Image(systemName: "crown.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .orange.opacity(0.5), radius: 20)
            }

            VStack(spacing: 10) {
                Text("Unlock the Full Rift")
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)

                Text("Start your free trial and get everything")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 4)

            // Benefits
            VStack(spacing: 10) {
                PaywallBenefit(icon: "sparkles", text: "Unlimited AI creature card generation")
                PaywallBenefit(icon: "speaker.wave.3.fill", text: "Voice-guided Rift Guide companion")
                PaywallBenefit(icon: "diamond.fill", text: "Daily Rift Gem bonus (50/day)")
                PaywallBenefit(icon: "arrow.up.circle.fill", text: "2x XP boost on all activities")
                PaywallBenefit(icon: "crown.fill", text: "Exclusive seasonal creatures & cosmetics")
                PaywallBenefit(icon: "bolt.shield.fill", text: "Priority matchmaking in PvP")
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer()

            // Trial CTA
            VStack(spacing: 8) {
                Button(action: startFreeTrial) {
                    VStack(spacing: 4) {
                        Text("Start Free Trial")
                            .font(.headline.weight(.black))
                        Text("7 days free, then $4.99/month")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow.opacity(0.9), .orange],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: .orange.opacity(0.4), radius: 12)
                }
                .padding(.horizontal, 32)

                Text("Cancel anytime. No charge for 7 days.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))

                Button(action: skipPaywall) {
                    Text("Continue with limited features")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.3))
                        .underline()
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 30)

            // Legal
            HStack(spacing: 16) {
                Button("Terms") {}
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
                Button("Privacy") {}
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
                Button("Subscription Terms") {}
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.bottom, 10)
        }
    }

    private func startFreeTrial() {
        HapticsService.shared.notification(.success)
        AudioService.shared.playSFX(.rareDrop)

        // Trigger StoreKit subscription with introductory offer (1-week free)
        Task {
            await EconomyManager.shared.loadProducts()
            if let product = EconomyManager.shared.availableProducts.first(where: { $0.id == EconomyManager.ProductIDs.monthlySubscription }) {
                _ = try? await EconomyManager.shared.purchase(product)
            }
            // Proceed regardless (StoreKit handles the trial)
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: "riftwalker_plus_active")
                withAnimation { currentPage = 6 }
            }
        }
    }

    private func skipPaywall() {
        withAnimation { currentPage = 6 }
    }

    // MARK: - Page 6: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: "location.fill.viewfinder")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 8) {
                Text("One Last Thing")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                Text("We need your location to place mythic creatures in the world around you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(spacing: 12) {
                PermissionRow(icon: "location.fill", title: "Location", description: "Required — places creatures near you", color: .blue)
                PermissionRow(icon: "camera.fill", title: "Camera", description: "Optional — AR creature encounters", color: .green)
                PermissionRow(icon: "bell.fill", title: "Notifications", description: "Optional — rare spawn alerts", color: .orange)
            }
            .padding(.horizontal)

            Spacer()

            OnboardingButton(title: "Start Exploring!") {
                LocationService.shared.requestAuthorization()
                progression.processLogin()
                AICompanionService.shared.onFirstLaunch()
                withAnimation { isOnboardingComplete = true }
            }
        }
        .padding()
    }
}

// MARK: - Onboarding Components

struct OnboardingButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: isEnabled ? [.blue, .purple] : [.gray],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: isEnabled ? .purple.opacity(0.3) : .clear, radius: 10)
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct PaywallBenefit: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.yellow)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding()
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
