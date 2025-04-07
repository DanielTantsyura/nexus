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
    case contact
    
    /// Profile editing screen
    case editProfile
    
    /// Create new contact screen
    case createContact
    
    /// Add new contact tab
    case addNew
    
    /// Home screen
    case home
    
    /// Create account screen
    case createAccount
    
    /// Settings screen
    case settings
}

/// Tab selection options for main tab view
enum TabSelection: Int {
    case network = 0
    case addNew = 1
    case profile = 2
}

/// Coordinator handling the app's navigation and state
final class AppCoordinator: ObservableObject {
    // MARK: - Published Properties
    
    /// Network manager for API communication
    @Published var networkManager = NetworkManager()
    
    /// Currently active screen
    @Published var activeScreen: ActiveScreen = .login
    
    /// Currently selected tab
    @Published var selectedTab: TabSelection = .network
    
    /// Navigation path for the current navigation stack
    @Published var navigationPath = NavigationPath()
    
    /// Navigation path for the network tab
    @Published var networkTabPath = NavigationPath()
    
    /// Navigation path for the profile tab
    @Published var profileTabPath = NavigationPath()
    
    /// Current login state
    @Published var isLoggedIn: Bool = false
    
    /// ID of the logged-in user
    @Published var userId: Int? = nil
    
    /// Track if initial loading has completed
    @Published var initialLoadComplete = false
    
    // MARK: - Private Properties
    
    /// Timer to retry loading data if needed
    private var loadTimer: Timer?
    
    /// Subscriptions for the coordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the coordinator
    init() {
        setupInitialState()
        
        // Set up listeners for login state changes
        self.networkManager.$isLoggedIn
            .receive(on: RunLoop.main)
            .sink { [weak self] isLoggedIn in
                self?.isLoggedIn = isLoggedIn
                
                // Update screen based on login state
                if isLoggedIn {
                    self?.activeScreen = .profile
                } else {
                    self?.userId = nil
                    self?.activeScreen = .login
                }
            }
            .store(in: &cancellables)
        
        // Listen for user ID changes from the network manager
        self.networkManager.$userId
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                self?.userId = userId
            }
            .store(in: &cancellables)
    }
    
    /// Clean up resources when deallocated
    deinit {
        loadTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Setup
    
    /// Set up the initial state of the coordinator
    private func setupInitialState() {
        // Check if a session can be restored
        if networkManager.isLoggedIn {
            activeScreen = .profile
            selectedTab = .profile
        } else {
            activeScreen = .login
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
    
    // MARK: - Navigation
    
    /// Navigate to the settings screen
    func navigateToSettings() {
        profileTabPath.append(ActiveScreen.settings)
    }
    
    /// Set the active tab
    /// - Parameter tab: The tab to select
    func selectTab(_ tab: TabSelection) {
        selectedTab = tab
        
        switch tab {
        case .network:
            activeScreen = .userList
            navigationPath = networkTabPath
        case .profile:
            activeScreen = .profile
            navigationPath = profileTabPath
        case .addNew:
            // Simply set the active screen to createContact
            // without adding to navigation stack
            activeScreen = .createContact
            // Use a fresh navigation path for this tab
            navigationPath = NavigationPath()
        }
    }
    
    /// Navigate to the user list screen
    func showUserListScreen() {
        if selectedTab == .network {
            networkTabPath = NavigationPath()
        } else {
            selectedTab = .network
            networkTabPath = NavigationPath()
        }
        navigationPath = networkTabPath
        activeScreen = .userList
    }
    
    /// Navigate to the user detail screen for the specified user
    /// - Parameter user: The user to display details for
    func showContact(_ user: User) {
        networkManager.selectedUser = user
        networkTabPath.append(user)
        navigationPath = networkTabPath
        activeScreen = .contact
        
        // Schedule a refresh signal to ensure profile data is displayed correctly
        networkManager.scheduleRefreshSignal(type: .profile, delay: 0.2)
    }
    
    /// Navigate back from user detail to user list
    func navigateBackFromContact() {
        // If we're showing user detail, go back to user list
        if activeScreen == .contact {
            networkTabPath.removeLast()
            navigationPath = networkTabPath
        }
        activeScreen = .userList
    }
    
    /// Generic navigate back method - currently just calls navigateBackFromContact
    func navigateBack() {
        // If on the contact screen, navigate back to user list
        if activeScreen == .contact {
            navigateBackFromContact()
        }
    }
    
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
    
    /// Navigate to the edit profile screen
    func showEditProfile() {
        profileTabPath.append(ActiveScreen.editProfile)
        navigationPath = profileTabPath
        activeScreen = .editProfile
    }
    
    /// Navigate to the create contact screen
    func showCreateContact() {
        // Simply call selectTab(.addNew) instead of manipulating the navigation path
        selectTab(.addNew)
    }
    
    /// Navigate to the create account screen
    func showCreateAccount() {
        // Present the CreateAccountView
        // Note: The actual presentation is handled by the LoginView's sheet
        activeScreen = .createAccount
    }
    
    /// Navigate back from create contact to home
    func backFromCreateContact() {
        // Return to the network tab
        selectTab(.network)
        
        // Refresh connections data when returning from contact creation
        refreshWithDelay()
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
            // Schedule a refresh signal after a delay to ensure data has loaded
            self?.networkManager.scheduleRefreshSignal(type: .profile, delay: 0.3)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Log out the current user and return to the login screen
    func logout() {
        networkManager.logout()
        activeScreen = .login
        navigationPath = NavigationPath()
        networkTabPath = NavigationPath()
        profileTabPath = NavigationPath()
    }
    
    // MARK: - Data Management
    
    /// Refreshes all data from the API
    func refresh() {
        networkManager.refreshAll()
    }
    
    /// Refreshes all data with a custom delay
    func refreshWithDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.refresh()
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
    }
}
