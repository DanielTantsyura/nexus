import SwiftUI

// MARK: - Main Content View

/// The main content view for the Nexus application
/// 
/// This view serves as the entry point and orchestrates navigation between different screens,
/// handling the transition from login to the main application interface.
struct ContentView: View {
    /// App coordinator that manages navigation and application state
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Group {
            if coordinator.activeScreen == .login {
                LoginView()
            } else {
                MainTabView()
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
    ContentView()
        .environmentObject(AppCoordinator())
}

