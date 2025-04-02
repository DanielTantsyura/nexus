import SwiftUI

@main
struct NexusApp: App {
    /// Shared coordinator instance
    @StateObject private var coordinator = AppCoordinator()
    
    init() {
        // Configure global appearance settings
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(coordinator)
        }
    }
    
    /// Configure the global appearance settings for the app
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        // Use standard appearance for all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}
