import SwiftUI

// MARK: - Onboarding View
// Researched: Best onboarding practices from Duolingo (93% completion rate).
// Rules: 1) Teach by DOING not reading. 2) Max 5 screens. 3) Ask for permissions in context.
// Pokemon GO's "catch your first Pokemon" = immediate dopamine hook.

struct OnboardingView: View {
    @StateObject private var progression = ProgressionManager.shared

    @Binding var isOnboardingComplete: Bool

    @State private var currentPage = 0
    @State private var username = ""
    @State private var selectedFaction: Faction?
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: currentPage)

            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                lorePage.tag(1)
                namePage.tag(2)
                factionPage.tag(3)
                permissionsPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(), value: currentPage)

            // Page indicator
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? .white : .white.opacity(0.3))
                            .frame(width: index == currentPage ? 10 : 6, height: index == currentPage ? 10 : 6)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) { animateIn = true }
        }
    }

    private var backgroundColors: [Color] {
        switch currentPage {
        case 0: return [.indigo, .black]
        case 1: return [.purple, .black]
        case 2: return [.blue, .black]
        case 3: return [selectedFaction?.color ?? .cyan, .black]
        case 4: return [.green.opacity(0.8), .black]
        default: return [.black, .black]
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 30) {
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animateIn ? 1 : 0.5)

                Image(systemName: "hurricane")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .rotationEffect(.degrees(animateIn ? 0 : -90))
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3), value: animateIn)

            VStack(spacing: 12) {
                Text("RIFT WALKERS")
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                    .opacity(animateIn ? 1 : 0)

                Text("Mythic Realms")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.cyan)
                    .opacity(animateIn ? 1 : 0)
            }

            Text("The barrier between our world and the mythological realms is breaking. Creatures from every legend walk among us.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            OnboardingButton(title: "Begin Your Journey") {
                withAnimation { currentPage = 1 }
            }
        }
        .padding()
    }

    // MARK: - Page 2: Lore

    private var lorePage: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mythology icons
            HStack(spacing: 16) {
                ForEach([Mythology.norse, .greek, .egyptian, .japanese, .celtic], id: \.self) { myth in
                    VStack(spacing: 4) {
                        Image(systemName: myth.icon)
                            .font(.title2)
                            .foregroundStyle(myth.color)
                        Text(myth.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Ancient Myths Made Real")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                Text("Explore your world to discover creatures from Norse, Greek, Egyptian, Japanese, Celtic, and more mythologies. Each with unique powers and deep lore.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            // Feature highlights
            VStack(spacing: 12) {
                FeatureRow(icon: "map.fill", text: "Real-world exploration", color: .green)
                FeatureRow(icon: "figure.fencing", text: "Epic turn-based battles", color: .red)
                FeatureRow(icon: "person.3.fill", text: "Guild wars & territory control", color: .blue)
                FeatureRow(icon: "sparkles", text: "Collect 100+ mythic creatures", color: .purple)
            }

            Spacer()

            OnboardingButton(title: "Continue") {
                withAnimation { currentPage = 2 }
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

            if username.count < 3 {
                Text("Minimum 3 characters")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            OnboardingButton(title: "Next", isEnabled: username.count >= 3) {
                progression.player.username = username
                progression.player.displayName = username
                withAnimation { currentPage = 3 }
            }
        }
        .padding()
    }

    // MARK: - Page 4: Faction Choice

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
                    Button(action: { withAnimation { selectedFaction = faction } }) {
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
                withAnimation { currentPage = 4 }
            }
        }
        .padding()
    }

    // MARK: - Page 5: Permissions

    private var permissionsPage: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("One Last Thing")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)

                Text("Rift Walkers needs your location to place creatures and territories in the real world around you.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(spacing: 12) {
                PermissionRow(icon: "location.fill", title: "Location", description: "Required to play", color: .blue)
                PermissionRow(icon: "camera.fill", title: "Camera", description: "Optional: AR mode", color: .green)
                PermissionRow(icon: "bell.fill", title: "Notifications", description: "Optional: Events & nearby alerts", color: .orange)
            }
            .padding(.horizontal)

            Spacer()

            OnboardingButton(title: "Start Exploring!") {
                LocationService.shared.requestAuthorization()
                progression.processLogin()
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
