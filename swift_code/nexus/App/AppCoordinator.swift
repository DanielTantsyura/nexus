import SwiftUI
import Combine

/// Centralized application coordinator that manages state and navigation
class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    /// Network manager for API communication
    @Published var networkManager = NetworkManager()
    
    /// Currently active screen
    @Published var activeScreen: ActiveScreen = .userList
    
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
        // Initial data loading
        refresh()
        
        // Set up a timer to check if data loaded successfully
        loadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            if self?.networkManager.users.isEmpty == true && self?.networkManager.errorMessage == nil {
                print("Initial load didn't get users, retrying...")
                self?.refresh()
            }
        }
    }
    
    deinit {
        loadTimer?.invalidate()
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to a user's detail view
    func showUserDetail(user: User) {
        print("Navigating to user detail for \(user.fullName) (ID: \(user.id))")
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
        navigationPath = NavigationPath()
        activeScreen = .userList
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
        case .userList:
            networkManager.fetchUsers()
        case .userDetail:
            if let user = networkManager.selectedUser {
                networkManager.getConnections(userId: user.id)
            }
        }
        
        // Set initial load complete after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.initialLoadComplete = true
        }
    }
}

/// Available application screens
enum ActiveScreen {
    case userList
    case userDetail
} 