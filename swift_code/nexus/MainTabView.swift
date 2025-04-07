import SwiftUI

/// Main tab view containing the primary application screens
struct MainTabView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - View
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $coordinator.selectedTab) {
                // Network Tab
                NavigationStack(path: $coordinator.networkTabPath) {
                    NetworkView()
                        .navigationDestination(for: User.self) { user in
                            ContactView(user: user)
                        }
                }
                .tabItem {
                    Label("Network", systemImage: "person.3")
                }
                .tag(TabSelection.network)
                
                // Add New Tab - hidden empty view
                NavigationStack {
                    // Still show the CreateContactView when this tab is selected
                    CreateContactView()
                }
                .tabItem { 
                    // Completely empty tab item
                }
                .tag(TabSelection.addNew)
                
                // Profile Tab
                NavigationStack(path: $coordinator.profileTabPath) {
                    ProfileView()
                        .navigationDestination(for: ActiveScreen.self) { screen in
                            switch screen {
                            default:
                                EmptyView()
                            }
                        }
                }
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(TabSelection.profile)
            }
            
            // Custom Add Button
            Button(action: {
                coordinator.selectedTab = .addNew
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: coordinator.selectedTab == .addNew ? 20 : 30, weight: .bold))
                    Text("Add")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(width: coordinator.selectedTab == .addNew ? 70 : 100, height: coordinator.selectedTab == .addNew ? 70 : 100)
                .background(coordinator.selectedTab == .addNew ? Color.gray : Color.green)
                .clipShape(Capsule())
            }
            .offset(y: 8)
            .shadow(radius: 2)
        }
        .onChange(of: coordinator.selectedTab) { oldValue, newValue in
            coordinator.selectTab(newValue)
        }
    }
}

/// View that serves as the entry point for the application
struct MainView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - View
    
    var body: some View {
        Group {
            if coordinator.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

/// Loading view displayed during data operations
struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.8))
            )
        }
    }
}

// MARK: - Navigation Extensions

extension View {
    /// Conditionally applies a navigation title
    /// - Parameters:
    ///   - title: The title to display
    ///   - displayMode: How to display the title
    /// - Returns: A view with the navigation title applied
    func conditionalNavigationTitle(_ title: String, displayMode: NavigationBarItem.TitleDisplayMode = .automatic) -> some View {
        self.navigationTitle(title)
            .navigationBarTitleDisplayMode(displayMode)
    }
    
    /// Adds a back button to the navigation bar
    /// - Parameter action: Action to perform when back is tapped
    /// - Returns: A view with the back button added
    func withBackButton(action: @escaping () -> Void) -> some View {
        self.navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: action) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(AppCoordinator())
} 