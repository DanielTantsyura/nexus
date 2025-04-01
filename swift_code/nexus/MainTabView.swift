import SwiftUI

/// Main tab-based view for the application after login
struct MainTabView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// Computed property to bind to TabView selection
    private var selection: Binding<Int> {
        Binding(
            get: { self.coordinator.selectedTab.rawValue },
            set: { 
                let tab = TabSelection(rawValue: $0) ?? .network
                self.coordinator.selectTab(tab)
            }
        )
    }
    
    // MARK: - View Body
    
    var body: some View {
        TabView(selection: selection) {
            // Network Tab
            networkTabView
                .tabItem {
                    Text("Network")
                }
                .tag(TabSelection.network.rawValue)
            
            // Add New Tab (Middle Button)
            addNewTabView
                .tabItem {
                    Text("")
                }
                .tag(TabSelection.addNew.rawValue)
            
            // Profile Tab
            profileTabView
                .tabItem {
                    Text("Profile")
                }
                .tag(TabSelection.profile.rawValue)
        }
        .overlay(
            // Custom middle button
            VStack {
                Spacer()
                addButton
                    .offset(y: -5) // Adjust to position above tab bar
            }
        )
        .onAppear {
            // Style tab bar to have text only
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // Normal tabs
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.lightGray
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            
            // Selected tabs
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.black
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            
            // Hide middle tab item text
            appearance.stackedLayoutAppearance.normal.iconColor = .clear
            appearance.stackedLayoutAppearance.selected.iconColor = .clear
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
    
    // MARK: - Tab Components
    
    /// Network tab view (User List)
    private var networkTabView: some View {
        NavigationStack(path: $coordinator.networkTabPath) {
            UserListView()
                .navigationTitle("Nexus")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: User.self) { user in
                    UserDetailView(user: user)
                }
                .navigationDestination(for: ActiveScreen.self) { screen in
                    switch screen {
                    case .editProfile:
                        EditProfileView()
                    default:
                        UserListView()
                    }
                }
        }
    }
    
    /// Add New tab (placeholder)
    private var addNewTabView: some View {
        NavigationStack {
            AddNewPlaceholderView()
        }
    }
    
    /// Profile tab view (HomeView)
    private var profileTabView: some View {
        NavigationStack(path: $coordinator.profileTabPath) {
            HomeView()
                .navigationTitle("Profile")
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
    
    /// Custom add button in the middle of the tab bar
    private var addButton: some View {
        Button(action: {
            coordinator.selectTab(.addNew)
        }) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 56, height: 56)
                    .shadow(radius: 2)
                
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    MainTabView()
        .environmentObject(AppCoordinator())
} 