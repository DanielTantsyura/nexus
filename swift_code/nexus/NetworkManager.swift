import SwiftUI
import Combine
import Foundation

/// Manages all network communication with the Nexus API
class NetworkManager: ObservableObject {
    // MARK: - Published Properties
    
    /// List of all users in the system
    @Published var users: [User] = []
    
    /// Currently selected user for detail view
    @Published var selectedUser: User?
    
    /// Current logged-in user's profile
    @Published var currentUser: User?
    
    /// Connections for the selected user
    @Published var connections: [Connection] = []
    
    /// Whether a network request is in progress
    @Published var isLoading = false
    
    /// Error message to display, if any
    @Published var errorMessage: String?
    
    /// Whether the user is logged in
    @Published var isLoggedIn = false
    
    /// ID of the currently logged-in user
    @Published var userId: Int? = nil
    
    // MARK: - Private Properties
    
    /// Set of cancellables for Combine operations
    private var cancellables = Set<AnyCancellable>()
    
    /// Base URL for the API
    private let baseURL: String = {
        #if targetEnvironment(simulator)
        return "http://127.0.0.1:8080"  // IPv4 localhost for simulator
        #else
        return "http://10.0.0.232:8080"  // Use your Mac's IP for physical devices
        #endif
    }()
    
    // MARK: - Initialization
    
    /// Initialize the network manager and restore session if available
    init() {
        restoreSession()
    }
    
    // MARK: - Session Management
    
    /// Restores user session from UserDefaults if available
    private func restoreSession() {
        if let savedUserId = UserDefaults.standard.object(forKey: "userId") as? Int {
            self.userId = savedUserId
            self.isLoggedIn = true
            self.fetchCurrentUser()
        }
    }
    
    /// Saves the user session to UserDefaults
    private func saveSession(userId: Int) {
        UserDefaults.standard.set(userId, forKey: "userId")
    }
    
    // MARK: - Authentication Methods
    
    /// Authenticates a user with the given credentials
    /// - Parameters:
    ///   - username: The user's username
    ///   - password: The user's password
    ///   - completion: Closure called with result of authentication
    func login(username: String, password: String, completion: @escaping (Result<Int, AuthError>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/login") else {
            handleError("Invalid URL", error: .unknownError, completion: completion)
            return
        }
        
        let loginData = Login(username: username, password: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            handleError("Failed to encode login data", error: .unknownError, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        print("Sending login request with data: \(String(data: jsonData, encoding: .utf8) ?? "")")  // Debug print
        
        // Set a timeout to prevent UI being stuck in loading state
        let timeoutTask = DispatchWorkItem {
            print("Login request timed out")
            DispatchQueue.main.async {
                if self.isLoading {
                    self.isLoading = false
                    self.errorMessage = "Request timed out. Please try again."
                    completion(.failure(.networkError))
                }
            }
        }
        
        // Schedule the timeout task
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: timeoutTask)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Cancel the timeout task since we got a response
            timeoutTask.cancel()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.handleError(error.localizedDescription, error: .networkError, completion: completion)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Login response status code: \(httpResponse.statusCode)")  // Debug print
                    
                    if httpResponse.statusCode == 401 {
                        self.handleError("Invalid username or password", error: .invalidCredentials, completion: completion)
                        return
                    }
                    
                    if !(200...299).contains(httpResponse.statusCode) {
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("Server error response: \(errorString)")  // Debug print
                        }
                        self.handleError("Server error: \(httpResponse.statusCode)", error: .unknownError, completion: completion)
                        return
                    }
                }
                
                guard let data = data else {
                    self.handleError("No data received", error: .networkError, completion: completion)
                    return
                }
                
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    self.userId = loginResponse.userId
                    self.isLoggedIn = true
                    
                    // Save session and fetch user data
                    self.saveSession(userId: loginResponse.userId)
                    
                    // If user data is included in the response, use it directly
                    if let user = loginResponse.user {
                        self.currentUser = user
                    } else {
                        self.fetchCurrentUser()
                    }
                    
                    completion(.success(loginResponse.userId))
                } catch {
                    print("Login response decode error: \(error)")  // Debug print
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("Raw response data: \(dataString)")  // Debug print
                    }
                    self.handleError("Failed to decode login response: \(error.localizedDescription)", 
                                    error: .unknownError, 
                                    completion: completion)
                }
            }
        }.resume()
    }
    
    /// Updates the last login timestamp for the current user when the app is opened
    func updateLastLogin() {
        guard let userId = self.userId else { return }
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/update-last-login") else {
            print("Invalid URL for updating last login")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error updating last login: \(error.localizedDescription)")
                // Continue app operation, don't log out for this error
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Server error updating last login: \(httpResponse.statusCode)")
                // Continue app operation, don't log out for this error
                return
            }
        }.resume()
    }
    
    /// Logs out the current user by clearing session data
    func logout() {
        // Make sure to reset loading state to false so login screen shows login button
        isLoading = false 
        
        // Clear error message as well to ensure a clean login screen
        errorMessage = nil
        
        // Reset user data
        userId = nil
        currentUser = nil
        isLoggedIn = false
        
        // Clear stored credentials
        UserDefaults.standard.removeObject(forKey: "userId")
        
        // Force UI update
        objectWillChange.send()
    }
    
    // MARK: - User API Methods
    
    /// Fetches the current user's profile information
    func fetchCurrentUser() {
        guard let userId = self.userId else { return }
        print("Fetching current user with ID: \(userId)")
        
        // Store the old user to compare later
        let oldUser = self.currentUser
        let hadNoUser = oldUser == nil
        
        fetchUser(withId: userId, retryCount: 3) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let user):
                print("Successfully fetched user with ID: \(userId)")
                
                // Only clear and reset with a delay if there was no previous user
                // or if the data has actually changed
                let dataChanged = oldUser == nil || oldUser?.id != user.id || 
                                  oldUser?.username != user.username ||
                                  oldUser?.firstName != user.firstName ||
                                  oldUser?.lastName != user.lastName
                
                if dataChanged {
                    print("User data has changed or was previously nil, updating UI")
                    
                    // Only clear first if we previously had data
                    if !hadNoUser {
                        self.currentUser = nil
                        
                        // Short delay to ensure the UI catches the change
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.currentUser = user
                            // UI should update automatically due to the change
                        }
                    } else {
                        // If we had no user before, just set it directly
                        self.currentUser = user
                    }
                } else {
                    print("User data unchanged, not triggering UI update")
                    // If nothing changed, don't force a UI update
                    self.currentUser = user
                }
                
            case .failure(let error):
                // Only show error message if it's not a 404 (which could happen during app setup)
                if (error as NSError).code != 404 {
                    self.errorMessage = error.localizedDescription
                    print("Error fetching current user: \(error.localizedDescription)")
                } else {
                    print("User with ID \(userId) not found (404)")
                }
                
                // Even on error, trigger a UI update if we previously had data
                // This ensures the UI shows the error state
                if oldUser != nil {
                    print("Had previous user data but fetch failed, forcing UI update")
                    DispatchQueue.main.async {
                        self.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    /// Fetches a user by their ID with retry functionality
    private func fetchUser(withId id: Int, retryCount: Int = 3, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(id)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let request = URLRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    self.retryFetchUserIfNeeded(id: id, retryCount: retryCount, error: error, completion: completion)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    guard let data = data else {
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                        return
                    }
                    
                    do {
                        let user = try JSONDecoder().decode(User.self, from: data)
                        completion(.success(user))
                    } catch {
                        print("Error decoding user: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                    
                case 404:
                    completion(.failure(NSError(domain: "", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                    
                default:
                    if retryCount > 0 {
                        print("Retrying fetchUser (attempt \(4-retryCount)/3) for user ID \(id)")
                        self.fetchUser(withId: id, retryCount: retryCount - 1, completion: completion)
                    } else {
                        completion(.failure(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])))
                    }
                }
            }
        }.resume()
    }
    
    /// Retries fetching user data if needed
    private func retryFetchUserIfNeeded(id: Int, retryCount: Int, error: Error, completion: @escaping (Result<User, Error>) -> Void) {
        if retryCount > 0 {
            print("Retrying fetchUser (attempt \(4-retryCount)/3) for user ID \(id)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.fetchUser(withId: id, retryCount: retryCount - 1, completion: completion)
            }
        } else {
            completion(.failure(error))
        }
    }
    
    /// Searches for users matching the given search term
    /// - Parameter term: The search term to find users by
    func searchUsers(term: String) {
        guard !term.isEmpty else {
            fetchAllUsers()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            isLoading = false
            errorMessage = "Invalid search term"
            return
        }
        
        guard let url = URL(string: "\(baseURL)/users/search?q=\(encodedTerm)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self.users = users
                } catch {
                    self.errorMessage = "Failed to decode users: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Fetches all users from the server
    func fetchAllUsers() {
        fetchAllUsersInternal(currentRetry: 0, maxRetries: 3)
    }
    
    /// Internal implementation of fetchAllUsers with retry functionality
    /// - Parameters:
    ///   - currentRetry: Current retry attempt
    ///   - maxRetries: Maximum number of retry attempts
    private func fetchAllUsersInternal(currentRetry: Int, maxRetries: Int) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        // Avoid caching issues - always get fresh data
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Set a timeout to prevent UI being stuck in loading state
        let timeoutTask = DispatchWorkItem { [weak self] in
            print("Fetch users request timed out")
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                // Don't show error message to avoid disrupting user experience
            }
        }
        
        // Schedule the timeout task with a reasonable timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeoutTask)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Cancel the timeout task since we got a response
            timeoutTask.cancel()
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Always set loading to false after fetch completes
                defer {
                    if currentRetry >= maxRetries {
                        self.isLoading = false
                    }
                }
                
                if let error = error {
                    // Network error with retry
                    print("Network error fetching users: \(error.localizedDescription)")
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    // Don't show error message to user to avoid disrupting the experience
                    // Keep using existing users array if not empty
                    if self.users.isEmpty {
                        print("Using empty users array after network error")
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Fetch users response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 500 || httpResponse.statusCode == 503 {
                        // Server error with retry
                        if currentRetry < maxRetries {
                            self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                            return
                        }
                        
                        // Don't show error message to user
                        return
                    } else if httpResponse.statusCode != 200 {
                        // Other HTTP error - log but don't disrupt user experience
                        print("Server error \(httpResponse.statusCode): Unable to fetch users")
                        return
                    }
                }
                
                guard let data = data else {
                    // No data with retry
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    print("No data received from server")
                    return
                }
                
                do {
                    // Try parsing response as regular JSON first
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = jsonObject["error"] as? String {
                        // Server returned an error object
                        print("Server error: \(errorMessage)")
                        if currentRetry < maxRetries {
                            self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        }
                        return
                    }
                    
                    let users = try JSONDecoder().decode([User].self, from: data)
                    
                    if !users.isEmpty {
                        // Clear and then set to ensure change is detected
                        let oldUsers = self.users
                        self.users = []
                        
                        // Add slight delay to ensure the UI catches the change
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.users = users
                            print("Successfully loaded \(users.count) users")
                            
                            // If there was no visible change, manually trigger observation
                            if users.count == oldUsers.count && !users.isEmpty {
                                self.objectWillChange.send()
                            }
                        }
                    } else if self.users.isEmpty {
                        // If we got an empty array and don't have existing users, retry
                        if currentRetry < maxRetries {
                            print("Received empty users array, retrying...")
                            self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                            return
                        }
                        
                        // Only set empty if we don't already have users and we're out of retries
                        print("Using empty users array after all retries")
                        self.users = []
                    }
                } catch {
                    // JSON decoding error with retry
                    print("Error decoding users: \(error.localizedDescription)")
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(dataString)")
                    }
                    
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    // Don't show error message to user to avoid disrupting the experience
                }
            }
        }.resume()
    }
    
    /// Retries fetching all users after a delay
    private func retryFetchAllUsers(currentRetry: Int, maxRetries: Int) {
        let retryDelay = Double(currentRetry + 1) * 0.7 // Increasing delay for each retry
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self = self else { return }
            print("Retrying fetchAllUsers (attempt \(currentRetry + 1)/\(maxRetries))")
            self.fetchAllUsersInternal(currentRetry: currentRetry + 1, maxRetries: maxRetries)
        }
    }
    
    /// Updates a user's profile information
    func updateUser(_ user: User, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(user.id)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(user) else {
            isLoading = false
            errorMessage = "Failed to encode user data"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // If this is the current user, update the stored user
                if self.currentUser?.id == user.id {
                    self.currentUser = user
                }
                
                // Update in users array if present
                if let index = self.users.firstIndex(where: { $0.id == user.id }) {
                    self.users[index] = user
                }
                
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Connection API Methods
    
    /// Fetches connections for a specific user
    /// - Parameters:
    ///   - userId: ID of the user to fetch connections for
    ///   - completion: Optional closure called when connections are loaded
    func getConnections(userId: Int, completion: ((Bool) -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion?(false)
            return
        }
        
        print("Fetching connections for user ID: \(userId)")
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { 
                    completion?(false)
                    return 
                }
                
                self.isLoading = false
                
                if let error = error {
                    print("Network error retrieving connections: \(error.localizedDescription)")
                    // Don't show error to user, just keep existing connections if any
                    completion?(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Get connections response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 404 {
                        // User has no connections, clear existing
                        print("User has no connections (404 response)")
                        self.connections = []
                        completion?(true)  // Still consider this a successful request
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        print("Server error retrieving connections: \(httpResponse.statusCode)")
                        // Don't show error to user
                        completion?(false)
                        return
                    }
                }
                
                guard let data = data else {
                    print("No connection data received")
                    completion?(false)
                    return
                }
                
                do {
                    // Print raw JSON for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw connection data: \(jsonString)")
                    }
                    
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    print("Successfully decoded \(connections.count) connections")
                    
                    // Ensure UI updates by explicitly setting on main thread
                    // and triggering a change notification even if the array is empty
                    let oldConnections = self.connections
                    self.connections = []  // Clear first to ensure change is detected
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.connections = connections
                        print("Successfully loaded \(connections.count) connections into NetworkManager")
                        
                        // If there's no change in connections but we got an empty array,
                        // manually trigger observation
                        if connections.isEmpty && oldConnections.isEmpty {
                            self.objectWillChange.send()
                        }
                        
                        completion?(true)
                    }
                } catch {
                    print("Failed to decode connections: \(error.localizedDescription)")
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(dataString)")
                    }
                    completion?(false)
                }
            }
        }.resume()
    }
    
    /// Adds a connection between two users
    /// - Parameters:
    ///   - userId: ID of the user to add the connection to
    ///   - connectionId: ID of the user to connect with (optional, server can determine from text)
    ///   - relationshipType: Description of how the users know each other
    ///   - tags: Optional array of tags to categorize the connection
    ///   - completion: Closure called with success/failure result
    func addConnection(userId: Int, connectionId: Int?, relationshipType: String, tags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            handleError("Invalid URL")
            completion(false)
            return
        }
        
        // Prepare request data
        var requestData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId ?? 0,
            "relationship_type": relationshipType
        ]
        
        if let tags = tags, !tags.isEmpty {
            requestData["tags"] = tags.joined(separator: ",")
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            handleError("Failed to encode request data")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.handleError(error.localizedDescription)
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.handleError("Invalid response")
                    completion(false)
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    self.handleError("Server error: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }.resume()
    }
    
    /// Removes a connection between two users
    func removeConnection(userId: Int, connectionId: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        // Create request data
        let requestData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            isLoading = false
            errorMessage = "Failed to encode request data"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Remove from local connections array
                self.connections.removeAll { $0.id == connectionId }
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Contact Creation

    /// Creates a new contact from text description
    /// - Parameters:
    ///   - userId: ID of the user creating the contact
    ///   - contactText: Free-form text describing the contact
    ///   - relationshipType: Optional relationship type (defaults to "contact")
    ///   - completion: Closure called with success/failure result
    func createContact(userId: Int, contactText: String, relationshipType: String = "contact", completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/contacts/create") else {
            handleError("Invalid URL")
            completion(false)
            return
        }
        
        // Prepare request data
        let requestData: [String: Any] = [
            "user_id": userId,
            "contact_text": contactText,
            "relationship_type": relationshipType
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestData) else {
            handleError("Failed to encode request data")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.handleError(error.localizedDescription)
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.handleError("Invalid response")
                    completion(false)
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    self.handleError("Server error: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Handles API errors and executes the completion handler
    private func handleError(_ message: String, error: AuthError? = nil, completion: ((Result<Int, AuthError>) -> Void)? = nil) {
        // Always ensure isLoading is set to false to prevent UI being stuck in loading state
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = message
            if let error = error, let completion = completion {
                completion(.failure(error))
            }
        }
    }
    
    /// Refreshes all data from the server
    func refreshAll() {
        guard let userId = self.userId else {
            // If no user ID, we're not logged in, so don't try to refresh
            return
        }
        
        // Fetch current user
        fetchCurrentUser()
        
        // Fetch all users
        fetchAllUsers()
        
        // Get connections
        getConnections(userId: userId)
        
        // Update last login
        updateLastLogin()
    }
    
    /// Fetches recent tags used by the current user
    /// - Parameter completion: Closure called with result of operation
    func fetchUserRecentTags(completion: @escaping (Result<[String], Error>) -> Void) {
        if userId == nil {
            completion(.failure(NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])))
            return
        }
        
        // Simplified implementation - use default tags since we don't have a dedicated tags endpoint
        let defaultTags = ["friend", "family", "work", "school", "neighbor"]
        completion(.success(defaultTags))
    }
}
