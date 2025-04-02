import SwiftUI

@main
struct NexusApp: App {
    /// Shared coordinator instance
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(coordinator)
        }
    }
}
