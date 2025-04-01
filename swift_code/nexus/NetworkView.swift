import SwiftUI

// MARK: - Main Network View

/// The main content view for the Nexus application
/// 
/// This view serves as the entry point and orchestrates navigation between different screens,
/// handling the transition from login to the main application interface.
struct NetworkView: View {
    /// App coordinator that manages navigation and application state
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        // Only show MainTabView after login, otherwise show LoginView with no tab bar
        if coordinator.activeScreen == .login {
            LoginView()
                .onAppear {
                    // Hide tab bar when login screen appears
                    UITabBar.appearance().isHidden = true
                }
        } else {
            MainTabView()
                .onAppear {
                    // Show tab bar when main app appears
                    UITabBar.appearance().isHidden = false
                }
        }
    }
}

// MARK: - Environment Values

/// Custom environment key for controlling swipe navigation gestures
struct SwipeNavigationGestureKey: EnvironmentKey {
    /// Default value for the swipe gesture (enabled by default)
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Controls whether swipe navigation gestures are enabled
    var swipeNavigationGestureEnabled: Bool {
        get { self[SwipeNavigationGestureKey.self] }
        set { self[SwipeNavigationGestureKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    NetworkView()
        .environmentObject(AppCoordinator())
}

