import SwiftUI
import Combine

/// Available application screens
enum ActiveScreen: Equatable {
    /// Login screen
    case login
    
    /// Home dashboard screen
    case home
    
    /// List of all users
    case userList
    
    /// Detailed view of a specific user
    case userDetail
    
    /// Profile editing screen
    case editProfile
    
    /// Tab selection enum
    case addNew
}

/// Available tab selections
enum TabSelection: Int {
    case network = 0
    case addNew = 1
    case profile = 2
}

/// Centralized application coordinator that manages state and navigation
final class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    /// Network manager for API communication
    @Published var networkManager = NetworkManager()
    
    /// Currently active screen
    @Published var activeScreen: ActiveScreen = .login
    
    /// Current navigation path
    @Published var navigationPath = NavigationPath()
    
    /// Track if initial loading has completed
    @Published var initialLoadComplete = false
    
    /// Currently selected tab
    @Published var selectedTab: TabSelection = .network
    
    /// Network tab navigation path
    @Published var networkTabPath = NavigationPath()
    
    /// Profile tab navigation path
    @Published var profileTabPath = NavigationPath()
    
    // MARK: - Private Properties
    
    /// Timer to retry loading data if needed
    private var loadTimer: Timer?
    
    // MARK: - Lifecycle
    
    /// Initialize the coordinator
    init() {
        setupInitialState()
    }
    
    deinit {
        loadTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    /// Set up the initial state of the coordinator
    private func setupInitialState() {
        // Check if user is already logged in
        if networkManager.isLoggedIn {
            activeScreen = .home
            refreshData()
        }
        
        // Set up a timer to check if data loaded successfully
        loadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            if self.networkManager.isLoggedIn && 
               self.networkManager.users.isEmpty && 
               self.networkManager.errorMessage == nil {
                self.refresh()
            }
        }
    }
    
    // MARK: - Tab Navigation
    
    /// Set the active tab
    /// - Parameter tab: The tab to select
    func selectTab(_ tab: TabSelection) {
        selectedTab = tab
        
        // Update current navigation path based on selected tab
        switch tab {
        case .network:
            navigationPath = networkTabPath
            activeScreen = .userList
        case .profile:
            navigationPath = profileTabPath
            activeScreen = .home
        case .addNew:
            // Just set the active screen, no navigation path changes
            activeScreen = .addNew
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Handle user login
    /// - Parameters:
    ///   - username: The username to log in with
    ///   - password: The password to authenticate with
    ///   - completion: Closure called with success flag
    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        networkManager.login(username: username, password: password) { [weak self] result in
            switch result {
            case .success(_):
                self?.activeScreen = .userList
                self?.selectedTab = .network
                self?.refresh()
                completion(true)
            case .failure(_):
                completion(false)
            }
        }
    }
    
    /// Handle user logout
    func logout() {
        networkManager.logout()
        activeScreen = .login
        navigationPath = NavigationPath()
        networkTabPath = NavigationPath()
        profileTabPath = NavigationPath()
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to the home screen
    func showHomeScreen() {
        // Only clear path when explicitly returning to home
        if selectedTab == .profile {
            profileTabPath = NavigationPath()
        } else {
            selectedTab = .profile
            profileTabPath = NavigationPath()
        }
        navigationPath = profileTabPath
        activeScreen = .home
    }
    
    /// Navigate to the user list screen
    func showUserList() {
        if selectedTab == .network {
            networkTabPath = NavigationPath()
        } else {
            selectedTab = .network
            networkTabPath = NavigationPath()
        }
        navigationPath = networkTabPath
        activeScreen = .userList
    }
    
    /// Navigate to the edit profile screen
    func showEditProfile() {
        profileTabPath.append(ActiveScreen.editProfile)
        navigationPath = profileTabPath
        activeScreen = .editProfile
    }
    
    /// Navigate back from edit profile to home
    func backFromEditProfile() {
        // No need to clear navigation path, the system will handle this
        if !profileTabPath.isEmpty {
            profileTabPath.removeLast()
        }
        navigationPath = profileTabPath
        activeScreen = .home
        
        // Ensure user data is refreshed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.networkManager.fetchCurrentUser()
        }
    }
    
    /// Navigate to a user's detail view
    /// - Parameter user: The user to display details for
    func showUserDetail(user: User) {
        // Store selected user
        networkManager.selectedUser = user
        
        // Ensure connections are cleared before navigating
        networkManager.connections = []
        
        // Set the active screen first
        activeScreen = .userDetail
        
        // First fetch connections
        networkManager.getConnections(userId: user.id)
        
        // Then navigate based on which tab we're in
        if selectedTab == .network {
            networkTabPath.append(user)
            navigationPath = networkTabPath
        } else {
            profileTabPath.append(user)
            navigationPath = profileTabPath
        }
        
        // Schedule another connection fetch after navigation is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.networkManager.getConnections(userId: user.id)
        }
    }
    
    /// Navigate back to the user list
    func backToUserList() {
        // No need to clear navigation path, the system will handle this
        if selectedTab == .network {
            if !networkTabPath.isEmpty {
                networkTabPath.removeLast()
            }
            navigationPath = networkTabPath
        } else {
            if !profileTabPath.isEmpty {
                profileTabPath.removeLast()
            }
            navigationPath = profileTabPath
        }
        
        // Then set the active screen
        activeScreen = .userList
        
        // Ensure user list is refreshed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.networkManager.fetchUsers()
        }
    }
    
    // MARK: - Data Methods
    
    /// Refresh the current data
    func refreshData() {
        refresh()
    }
    
    // MARK: - Private Methods
    
    /// Internal refresh method based on the active screen
    private func refresh() {
        initialLoadComplete = false
        networkManager.isLoading = true
        
        // Clear any previous error
        networkManager.errorMessage = nil
        
        switch activeScreen {
        case .login:
            // Nothing to refresh on login screen
            break
            
        case .home:
            refreshHomeScreen()
            
        case .userList:
            networkManager.fetchUsers()
            
        case .userDetail:
            if let user = networkManager.selectedUser {
                networkManager.getConnections(userId: user.id)
            }
            
        case .editProfile:
            if networkManager.userId != nil {
                networkManager.fetchCurrentUser()
            }
            
        case .addNew:
            // Nothing to refresh for now on add new screen
            break
        }
        
        // Set initial load complete after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.initialLoadComplete = true
        }
    }
    
    /// Refreshes data specific to the home screen
    private func refreshHomeScreen() {
        if networkManager.userId != nil {
            networkManager.fetchCurrentUser()
            
            // After a small delay, fetch the user list as well
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.networkManager.fetchUsers()
            }
        }
    }
} 