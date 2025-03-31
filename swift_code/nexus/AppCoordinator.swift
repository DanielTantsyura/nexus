import SwiftUI
import Combine

/// Available application screens
enum ActiveScreen {
    case login
    case home
    case userList
    case userDetail
    case editProfile
}

/// Centralized application coordinator that manages state and navigation
class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    /// Network manager for API communication
    @Published var networkManager = NetworkManager()
    
    /// Currently active screen
    @Published var activeScreen: ActiveScreen = .login
    
    /// Current navigation path
    @Published var navigationPath = NavigationPath()
    
    /// Track if initial loading has completed
    @Published var initialLoadComplete = false
    
    // MARK: - Private Properties
    
    /// Timer to retry loading data if needed
    private var loadTimer: Timer?
    
    // MARK: - Lifecycle
    
    /// Initialize the coordinator
    init() {
        // Check if user is already logged in
        if networkManager.isLoggedIn {
            activeScreen = .home
            refreshData()
        }
        
        // Set up a timer to check if data loaded successfully
        loadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            if self?.networkManager.isLoggedIn == true && 
               self?.networkManager.users.isEmpty == true && 
               self?.networkManager.errorMessage == nil {
                print("Initial load didn't get users, retrying...")
                self?.refresh()
            }
        }
    }
    
    deinit {
        loadTimer?.invalidate()
    }
    
    // MARK: - Authentication Methods
    
    /// Handle user login
    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        networkManager.login(username: username, password: password) { [weak self] result in
            switch result {
            case .success(_):
                self?.activeScreen = .home
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
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to the home screen
    func showHomeScreen() {
        // Only clear path when explicitly returning to home
        navigationPath = NavigationPath()
        activeScreen = .home
    }
    
    /// Navigate to the user list screen
    func showUserList() {
        // Add to navigation path instead of clearing it
        navigationPath.append(ActiveScreen.userList)
        activeScreen = .userList
    }
    
    /// Navigate to the edit profile screen
    func showEditProfile() {
        navigationPath.append(ActiveScreen.editProfile)
        activeScreen = .editProfile
    }
    
    /// Navigate back from edit profile to home
    func backFromEditProfile() {
        // No need to clear navigation path, the system will handle this
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        activeScreen = .home
        
        // Ensure user data is refreshed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.networkManager.fetchCurrentUser()
        }
    }
    
    /// Navigate to a user's detail view
    func showUserDetail(user: User) {
        print("Navigating to user detail for \(user.fullName) (ID: \(user.id))")
        // Store selected user
        networkManager.selectedUser = user
        
        // Ensure connections are cleared before navigating
        networkManager.connections = []
        
        // Set the active screen first
        activeScreen = .userDetail
        
        // First fetch connections
        networkManager.getConnections(userId: user.id)
        
        // Then navigate
        navigationPath.append(user)
        
        // Schedule another connection fetch after navigation is complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.networkManager.getConnections(userId: user.id)
        }
    }
    
    /// Navigate back to the user list
    func backToUserList() {
        // No need to clear navigation path, the system will handle this
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        
        // Then set the active screen
        activeScreen = .userList
        
        // Ensure user list is refreshed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.networkManager.fetchUsers()
        }
    }
    
    // MARK: - Data Methods
    
    /// Refresh the current data
    func refreshData() {
        refresh()
    }
    
    // MARK: - Private Methods
    
    /// Internal refresh method
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
            // On home screen, fetch both current user and all users
            if networkManager.userId != nil {
                networkManager.fetchCurrentUser()
                
                // After a small delay, fetch the user list as well
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.networkManager.fetchUsers()
                }
            }
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
        }
        
        // Set initial load complete after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.initialLoadComplete = true
        }
    }
} 