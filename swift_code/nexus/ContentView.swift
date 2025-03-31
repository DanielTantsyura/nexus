import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        Group {
            if coordinator.activeScreen == .login {
                LoginView()
            } else {
                mainNavigationView
            }
        }
    }
    
    // MARK: - Main Navigation
    
    var mainNavigationView: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            // Base view is always HomeView
            HomeView()
                .navigationTitle("Nexus")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
                .navigationDestination(for: ActiveScreen.self) { screen in
                    switch screen {
                    case .editProfile:
                        EditProfileView()
                    case .userList:
                        UserListView()
                            .navigationTitle("All Users")
                            .navigationBarTitleDisplayMode(.large)
                    default:
                        HomeView()
                    }
                }
        }
    }
}

// Custom environment key for disabling swipe gesture
struct SwipeNavigationGestureKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
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

