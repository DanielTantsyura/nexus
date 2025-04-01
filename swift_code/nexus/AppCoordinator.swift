import SwiftUI
import Combine

/// Available application screens
enum ActiveScreen: Equatable {
    /// Login screen
    case login
    
    /// Profile dashboard screen
    case profile
    
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
    
    // MARK: - Initialization
    
    /// Initialize the coordinator
    init() {
        setupInitialState()
    }
    
    /// Clean up resources when deallocated
    deinit {
        loadTimer?.invalidate()
    }
    
    // MARK: - Setup
    
    /// Set up the initial state of the coordinator
    private func setupInitialState() {
        // Check if user is already logged in
        if networkManager.isLoggedIn {
            activeScreen = .profile
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
        
        switch tab {
        case .network:
            navigationPath = networkTabPath
            activeScreen = .userList
        case .profile:
            navigationPath = profileTabPath
            activeScreen = .profile
        case .addNew:
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
    
    /// Navigate to the profile screen
    func showProfileScreen() {
        // Only clear path when explicitly returning to profile
        if selectedTab == .profile {
            profileTabPath = NavigationPath()
        } else {
            selectedTab = .profile
            profileTabPath = NavigationPath()
        }
        navigationPath = profileTabPath
        activeScreen = .profile
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
    
    /// Navigate back from edit profile to profile
    func backFromEditProfile() {
        if !profileTabPath.isEmpty {
            profileTabPath.removeLast()
        }
        navigationPath = profileTabPath
        activeScreen = .profile
        
        // Ensure user data is refreshed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.networkManager.fetchCurrentUser()
        }
    }
    
    /// Navigate to a user's detail view
    /// - Parameter user: The user to display details for
    func showUserDetail(user: User) {
        networkManager.selectedUser = user
        networkTabPath.append(user)
        navigationPath = networkTabPath
        activeScreen = .userDetail
    }
    
    /// Navigate back from user detail to user list
    func backFromUserDetail() {
        if !networkTabPath.isEmpty {
            networkTabPath.removeLast()
        }
        navigationPath = networkTabPath
        activeScreen = .userList
    }
    
    // MARK: - Data Management
    
    /// Refreshes all data from the API
    func refresh() {
        loadData()
    }
    
    /// Refreshes all data with a custom delay
    func refreshWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.loadData()
        }
    }
    
    /// Loads all required data from the API
    private func loadData() {
        guard networkManager.isLoggedIn else { return }
        
        networkManager.refreshAll()
        initialLoadComplete = true
    }
    
    /// Refreshes data as needed
    func refreshData() {
        guard networkManager.isLoggedIn else {
            // If not logged in, redirect to login screen
            if activeScreen != .login {
                activeScreen = .login
                navigationPath = NavigationPath()
                networkTabPath = NavigationPath()
                profileTabPath = NavigationPath()
            }
            return
        }
        
        // Clear any existing error before retrying
        networkManager.errorMessage = nil
        
        // Always fetch all users to ensure the list is up to date
        networkManager.fetchAllUsers()
        
        // Always refresh the current user to ensure latest data
        networkManager.fetchCurrentUser()
        
        // If we encounter session expiration or persistent errors, handle them
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            if let errorMessage = self.networkManager.errorMessage {
                if errorMessage.contains("session has expired") || 
                   errorMessage.contains("User not found") ||
                   (errorMessage.contains("404") && self.activeScreen == .profile) {
                    // Session expired, log out and show login
                    self.logout()
                }
                
                // Print debug info
                print("NetworkManager error: \(errorMessage)")
            }
        }
    }
} 