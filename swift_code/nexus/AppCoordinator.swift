import SwiftUI
import Combine

/// Represents the available tabs in the application
enum TabSelection: Int {
    case network = 0
    case profile = 1
    case addNew = 2
}

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
    
    /// Create new contact screen
    case createContact
    
    /// Home screen
    case home
    
    /// Add new screen
    case addNew
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
            // Update last login when the app is opened
            networkManager.updateLastLogin()
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
            // Simply set the active screen to createContact 
            // without adding to navigation stack
            activeScreen = .createContact
            // Use a fresh navigation path for this tab
            navigationPath = NavigationPath()
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
        print("Logging out - resetting app state and navigating to login screen")
        
        // Ensure NetworkManager is not in loading state
        networkManager.isLoading = false
        
        // First clear all navigation paths and state
        navigationPath = NavigationPath()
        networkTabPath = NavigationPath()
        profileTabPath = NavigationPath()
        
        // Reset the tab selection to ensure we're not stuck in a specific tab
        selectedTab = .network
        
        // Clear the user data
        networkManager.logout()
        
        // Finally set the active screen to login
        // This must happen after clearing other state
        activeScreen = .login
        
        // Force UI refresh
        objectWillChange.send()
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
        
        // Ensure user data is refreshed when navigating to profile, but only if missing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Only fetch user data if it's missing
            if self.networkManager.currentUser == nil {
                print("AppCoordinator: User data missing, fetching")
                self.networkManager.fetchCurrentUser()
                
                // Force UI update to ensure the view reflects the latest data
                // But only if data is still missing after the fetch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if self.networkManager.currentUser == nil {
                        print("AppCoordinator: Still no user data, forcing UI refresh")
                        self.objectWillChange.send()
                    } else {
                        print("AppCoordinator: User data loaded successfully, no forced refresh needed")
                    }
                }
            } else {
                print("AppCoordinator: User data already loaded, no fetch needed")
            }
        }
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
    
    /// Navigate to the create contact screen
    func showCreateContact() {
        // Simply switch to the addNew tab
        selectTab(.addNew)
    }
    
    /// Navigate back from create contact to home
    func backFromCreateContact() {
        // Return to the network tab
        selectTab(.network)
    }
    
    /// Navigate back from edit profile to home
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
        
        // Ensure connections are loaded for this user
        print("Loading connections for user ID: \(user.id)")
        networkManager.getConnections(userId: user.id)
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
    
    /// Automatically retries loading data when a view needs it
    /// - Parameters:
    ///   - check: A closure that returns true if data is loaded properly, false if data is missing
    ///   - action: The refresh action to perform when data is missing
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - interval: Seconds between retry attempts (default: 2.0)
    func autoRetryLoading(check: @escaping () -> Bool, action: @escaping () -> Void, maxAttempts: Int = 3, interval: TimeInterval = 2.0) {
        // Always perform the action at least once to ensure fresh data
        action()
        
        // If data is already loaded after the first attempt, we're done
        if check() {
            print("Data loaded successfully on first attempt")
            return
        }
        
        print("Initial data load incomplete, setting up auto-retry...")
        
        // Create a task that will retry loading the data
        let task = DispatchWorkItem {
            var attempts = 0
            
            func attemptRefresh() {
                // If data is loaded or we've reached max attempts, stop retrying
                if check() || attempts >= maxAttempts {
                    print("Auto-retry complete after \(attempts) attempts")
                    
                    // Force a UI update on the main thread - but only if data is still not loaded
                    // after max attempts (meaning we're stopping due to max attempts)
                    if !check() && attempts >= maxAttempts {
                        print("Auto-retry: Max attempts reached but data still not loaded. Forcing UI update")
                        DispatchQueue.main.async {
                            // Trigger an update by publishing a dummy change to activeScreen and back
                            let currentScreen = self.activeScreen
                            self.activeScreen = .login
                            self.activeScreen = currentScreen
                        }
                    } else {
                        print("Auto-retry: Data successfully loaded, no forced UI update needed")
                    }
                    return
                }
                
                // Increment attempts and try again
                attempts += 1
                print("Auto-retry attempt \(attempts)/\(maxAttempts)...")
                
                // Perform the refresh action
                action()
                
                // Schedule next attempt after the interval
                DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                    attemptRefresh()
                }
            }
            
            // Start the first attempt
            attemptRefresh()
        }
        
        // Start the task
        DispatchQueue.main.async(execute: task)
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
        
        // If on user detail screen, reload connections for that user
        if activeScreen == .userDetail, let selectedUser = networkManager.selectedUser {
            print("Refreshing connections for selected user: \(selectedUser.id)")
            networkManager.getConnections(userId: selectedUser.id)
        }
        
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