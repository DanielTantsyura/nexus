import SwiftUI

@main
struct NexusApp: App {
    @StateObject private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            NetworkView()
                .environmentObject(coordinator)
        }
    }
}
