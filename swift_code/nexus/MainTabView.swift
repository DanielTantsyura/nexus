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
        ZStack(alignment: .bottom) {
            // Main content
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
            
            // Custom middle button overlay positioned above the tab bar
            VStack {
                Spacer()
                addButton
                    .offset(y: -22) // Position in the middle (between -30 and -15)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // Style tab bar to have text only
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            
            // Normal tabs - larger font
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.lightGray,
                .font: UIFont.systemFont(ofSize: 20, weight: .medium)
            ]
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            
            // Selected tabs - larger font
            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.black,
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold)
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            
            // Hide middle tab item text
            appearance.stackedLayoutAppearance.normal.iconColor = .clear
            appearance.stackedLayoutAppearance.selected.iconColor = .clear
            
            // Adjust vertical positioning
            appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -5)
            appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -5)
            
            // Increase tab bar height
            let tabBarHeight: CGFloat = 80
            
            // Apply the custom appearance to the tab bar
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            
            // Increase the tab bar height
            UITabBar.appearance().frame.size.height = tabBarHeight
            UITabBar.appearance().bounds.size.height = tabBarHeight
            
            // Use fill equally to distribute tabs evenly
            UITabBar.appearance().itemPositioning = .fill
            
            // Create a custom layout using a subclass to adjust tab positioning
            setupTabBarItemPositioning()
        }
        .onChange(of: coordinator.activeScreen) { oldValue, newValue in
            // If active screen becomes login, ensure we properly handle logout
            if newValue == .login {
                print("MainTabView detected activeScreen change to .login")
                // Extra check to ensure we're logged out
                if coordinator.networkManager.isLoggedIn == false {
                    // This should trigger any parent views to show login screen
                    coordinator.objectWillChange.send()
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom) // Make tab bar extend to screen edges
    }
    
    // MARK: - Tab Bar Positioning
    
    /// Sets up custom tab bar item positioning
    private func setupTabBarItemPositioning() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                return
            }
            
            if let tabBarController = findTabBarController(in: rootViewController) {
                // Get the tab bar
                let tabBar = tabBarController.tabBar
                
                // Ensure we have 3 tab bar items
                guard let items = tabBar.items, items.count == 3 else { return }
                
                // Calculate tab offsets without needing screen width
                // Using fixed values for simplicity
                
                // Adjust the first tab (Network) - position in center of left half
                items[0].titlePositionAdjustment = UIOffset(horizontal: 42, vertical: 0)
                
                // Skip the middle tab (already hidden)
                
                // Adjust the last tab (Profile) - position in center of right half
                items[2].titlePositionAdjustment = UIOffset(horizontal: -42, vertical: 0)
            }
        }
    }
    
    /// Recursively finds the UITabBarController in the view controller hierarchy
    private func findTabBarController(in viewController: UIViewController) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        
        if let navigationController = viewController as? UINavigationController {
            return findTabBarController(in: navigationController.visibleViewController ?? navigationController)
        }
        
        if let presentedController = viewController.presentedViewController {
            return findTabBarController(in: presentedController)
        }
        
        return nil
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
                    case .createContact:
                        CreateContactView()
                    default:
                        UserListView()
                    }
                }
        }
    }
    
    /// Add New tab (placeholder)
    private var addNewTabView: some View {
        NavigationStack {
            CreateContactView()
                .navigationTitle("Add Contact")
                .navigationBarTitleDisplayMode(.large)
        }
    }
    
    /// Profile tab view (ProfileView)
    private var profileTabView: some View {
        NavigationStack(path: $coordinator.profileTabPath) {
            ProfileView()
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
                    case .createContact:
                        CreateContactView()
                            .navigationTitle("Add Contact")
                            .navigationBarTitleDisplayMode(.large)
                    default:
                        ProfileView()
                    }
                }
        }
    }
    
    /// Custom add button in the middle of the tab bar
    private var addButton: some View {
        Button(action: {
            // Switch to the Add New tab directly
            coordinator.selectTab(.addNew)
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.green)
                    .frame(width: 100, height: 50)
                    .shadow(radius: 2)
                
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                    
                    Text("Add")
                        .font(.system(size: 18, weight: .semibold))
                }
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