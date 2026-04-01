import SwiftUI

// MARK: - App Entry Point
// Researched: Immediate engagement is critical. <3 seconds to interactable content.
// Splash -> Onboarding (first launch only) -> Map (the game).

@main
struct RiftWalkersApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var progression = ProgressionManager.shared

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .preferredColorScheme(.dark)
                    .onAppear {
                        progression.processLogin()
                    }
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
