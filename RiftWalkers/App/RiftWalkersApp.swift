import SwiftUI

// MARK: - App Entry Point
// Researched: Immediate engagement is critical. <3 seconds to interactable content.
// Splash -> Onboarding (first launch only) -> Map (the game).

@main
struct RiftWalkersApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var progression = ProgressionManager.shared
    @StateObject private var persistence = GamePersistenceService.shared

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .preferredColorScheme(.dark)
                    .environmentObject(persistence)
                    .onAppear {
                        progression.processLogin()
                        Task {
                            await persistence.authenticateOrRegister()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .autoSaveTriggered)) { _ in
                        Task {
                            await persistence.syncToCloud(
                                player: progression.player,
                                creatures: progression.ownedCreatures,
                                items: progression.player.items
                            )
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                        persistence.saveLocally(player: progression.player, creatures: progression.ownedCreatures)
                        Task {
                            await persistence.syncToCloud(
                                player: progression.player,
                                creatures: progression.ownedCreatures,
                                items: progression.player.items
                            )
                        }
                    }
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
