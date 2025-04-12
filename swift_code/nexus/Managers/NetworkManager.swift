import SwiftUI
import Combine
import Foundation

/// The central manager that holds all shared state (`@Published`) and
/// delegates to sub-managers for auth, contacts, connections, tags, etc.
class NetworkManager: ObservableObject {
    // MARK: - Published Properties
    
    /// State properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    @Published var userId: Int? = nil
    @Published var refreshSignal = UUID()
    @Published var currentUserLoaded = false
    @Published var lastRefreshType: RefreshType = .none
    
    /// Data properties
    @Published var users: [User] = []
    @Published var selectedUser: User?
    @Published var currentUser: User?
    @Published var connections: [Connection] = []
    @Published var recentTags: [String] = []
    
    // MARK: - Sub-Managers (lazy initialized)
    lazy var authManager = AuthManager(networkManager: self)
    lazy var contactsManager = ContactsManager(networkManager: self)
    lazy var connectionsManager = ConnectionsManager(networkManager: self)
    lazy var tagsManager = TagsManager(networkManager: self)
    
    // MARK: - Private Properties
    private let queue = DispatchQueue(label: "com.nexus.networkmanager", attributes: .concurrent)
    var cancellables = Set<AnyCancellable>()
    
    /// Base URL for the API
    let baseURL: String = {
        let useLocalApi = ProcessInfo.processInfo.environment["USE_LOCAL_API"]?.lowercased() == "true"
        
        if useLocalApi {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8080"
            #else
            return UserDefaults.standard.string(forKey: "DevServerIP").map { "http://\($0):8080" } ?? "http://10.0.0.232:8080"
            #endif
        }
        
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? 
               UserDefaults.standard.string(forKey: "ApiBaseUrl") ?? 
               "https://nexus-production-6654.up.railway.app"
    }()
    
    /// Default request timeout in seconds
    private let defaultTimeout: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    /// Initialize the network manager and restore session if available
    init() {
        let useLocalApi = ProcessInfo.processInfo.environment["USE_LOCAL_API"]?.lowercased() == "true"
        print("API URL: \(baseURL) (using \(useLocalApi ? "local API" : "hosted Railway API"))")
        
        testApiConnection()
        
        // Restore session after initialization
        DispatchQueue.main.async { [weak self] in
            self?.authManager.restoreSession()
        }
    }
    
    /// Tests API connection on startup
    private func testApiConnection() {
        let useLocalApi = ProcessInfo.processInfo.environment["USE_LOCAL_API"]?.lowercased() == "true"
        if !useLocalApi, let testURL = URL(string: "\(baseURL)/diagnostic") {
            URLSession.shared.dataTask(with: testURL) { data, response, error in
                if let error = error {
                    print("API connection test failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse, 
                          let data = data, 
                          let responseString = String(data: data, encoding: .utf8) {
                    print("API test status: \(httpResponse.statusCode), response: \(responseString)")
                }
            }.resume()
        }
    }
    
    // MARK: - Thread-Safe Setters
    
    func setLoading(_ value: Bool) {
        DispatchQueue.main.async { self.isLoading = value }
    }
    
    func setErrorMessage(_ value: String?) {
        DispatchQueue.main.async { self.errorMessage = value }
    }
    
    func setUsers(_ value: [User]) {
        DispatchQueue.main.async { self.users = value }
    }
    
    func setCurrentUser(_ value: User?) {
        DispatchQueue.main.async { self.currentUser = value }
    }
    
    func setConnections(_ value: [Connection]) {
        DispatchQueue.main.async { self.connections = value }
    }
    
    func setLoggedIn(_ value: Bool) {
        DispatchQueue.main.async { self.isLoggedIn = value }
    }
    
    func setUserId(_ value: Int?) {
        DispatchQueue.main.async { self.userId = value }
    }
    
    func setRecentTags(_ value: [String]) {
        DispatchQueue.main.async { self.recentTags = value }
    }
    
    func setCurrentUserLoaded(_ value: Bool) {
        DispatchQueue.main.async { self.currentUserLoaded = value }
    }
    
    // MARK: - Public "Forwarding" Methods
    // These methods delegate to sub-managers
    
    // Auth Methods
    func restoreSession() -> Bool { authManager.restoreSession() }
    func login(username: String, password: String, completion: @escaping (Result<Int, AuthError>) -> Void) {
        authManager.login(username: username, password: password, completion: completion)
    }
    func logout() { authManager.logout() }
    func createLogin(userId: Int, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        authManager.createLogin(userId: userId, password: password, completion: completion)
    }
    func updateLastLogin() { authManager.updateLastLogin() }
    func createAccount(userData: [String: Any], username: String, password: String, completion: @escaping (Result<Int, Error>) -> Void) {
        authManager.createAccount(userData: userData, username: username, password: password, completion: completion)
    }
    func checkUsernameAvailability(_ username: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        authManager.checkUsernameAvailability(username, completion: completion)
    }
    
    // Contacts Methods
    func fetchCurrentUser() { contactsManager.fetchCurrentUser() }
    func fetchAllUsers() { contactsManager.fetchAllUsers() }
    func fetchUser(withId userId: Int, retryCount: Int = 0, completion: @escaping (Result<User, Error>) -> Void) {
        contactsManager.fetchUser(withId: userId, retryCount: retryCount, completion: completion)
    }
    func fetchUserByUsername(_ username: String, completion: @escaping (Result<User, Error>) -> Void) {
        contactsManager.fetchUserByUsername(username, completion: completion)
    }
    func searchUsers(term: String) { contactsManager.searchUsers(term: term) }
    func createContact(fromText text: String, tags: [String]? = nil, completion: @escaping (Result<Int, Error>) -> Void) {
        contactsManager.createContact(fromText: text, tags: tags, completion: completion)
    }
    func updateUser(userId: Int, userData: [String: Any], completion: @escaping (Result<Bool, Error>) -> Void) {
        contactsManager.updateUser(userId: userId, userData: userData, completion: completion)
    }
    func updateUser(_ user: User, completion: @escaping (Result<Bool, Error>) -> Void) {
        contactsManager.updateUser(user, completion: completion)
    }
    
    // Connections Methods
    func fetchUserConnections() { connectionsManager.fetchUserConnections() }
    func fetchConnections(forUserId userId: Int) { connectionsManager.fetchConnections(forUserId: userId) }
    func createConnection(contactId: Int, description: String, notes: String? = nil, tags: [String]? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        connectionsManager.createConnection(contactId: contactId, description: description, notes: notes, tags: tags, completion: completion)
    }
    func updateConnection(contactId: Int, description: String? = nil, notes: String? = nil, tags: [String]? = nil, whatTheyAreWorkingOn: String? = nil, updateTimestampOnly: Bool = false, completion: @escaping (Result<Bool, Error>) -> Void) {
        connectionsManager.updateConnection(contactId: contactId, description: description, notes: notes, tags: tags, whatTheyAreWorkingOn: whatTheyAreWorkingOn, updateTimestampOnly: updateTimestampOnly, completion: completion)
    }
    func updateConnectionTimestamp(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        connectionsManager.updateConnectionTimestamp(contactId: contactId, completion: completion)
    }
    func removeConnection(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        connectionsManager.removeConnection(contactId: contactId, completion: completion)
    }
    func deleteContact(contactId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        connectionsManager.deleteContact(contactId: contactId, completion: completion)
    }
    
    // Tags Methods
    func fetchRecentTags() { tagsManager.fetchRecentTags() }
    func fetchUserRecentTags(completion: @escaping (Result<[String], Error>) -> Void) {
        tagsManager.fetchUserRecentTags(completion: completion)
    }
    
    // MARK: - Helper / Shared Methods
    func createRequest(for url: URL, method: String = "GET", body: Data? = nil, timeout: TimeInterval? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add auth token if available
        if let userId = self.userId {
            request.setValue("\(userId)", forHTTPHeaderField: "X-User-ID")
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Refresh Management
    enum RefreshType {
        case none, currentUser, connections, profile, allUsers
    }

    /// Sends a refresh signal to notify all observers that data has changed
    func signalRefresh(type: RefreshType) {
        DispatchQueue.main.async {
            self.lastRefreshType = type
            self.refreshSignal = UUID()
        }
    }

    /// Schedules a refresh signal with a delay
    func scheduleRefreshSignal(type: RefreshType, delay: TimeInterval = 0.3) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.signalRefresh(type: type)
        }
    }
    
    /// Refreshes all data from the server
    func refreshAll() {
        // Reset loading state and flags
        setLoading(true)
        setErrorMessage(nil)
        setCurrentUserLoaded(false)
        
        // Fetch all required data
        if let userId = self.userId {
            fetchCurrentUser()
            fetchConnections(forUserId: userId)
            fetchRecentTags()
            updateLastLogin()
        }
        fetchAllUsers()
        
        // Schedule a delayed refresh signal
        scheduleRefreshSignal(type: .profile, delay: 0.5)
    }
} 