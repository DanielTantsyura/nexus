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
        
        guard let url = URL(string: "\(baseURL)/login/validate") else {
            handleError("Invalid URL", error: .unknownError, completion: completion)
            return
        }
        
        let loginData = Login(username: username, passkey: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            handleError("Failed to encode login data", error: .unknownError, completion: completion)
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
                    self.handleError(error.localizedDescription, error: .networkError, completion: completion)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self.handleError("Invalid username or password", error: .invalidCredentials, completion: completion)
                        return
                    }
                    
                    if !(200...299).contains(httpResponse.statusCode) {
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
                    self.fetchCurrentUser()
                    
                    completion(.success(loginResponse.userId))
                } catch {
                    self.handleError("Failed to decode login response: \(error.localizedDescription)", 
                                    error: .unknownError, 
                                    completion: completion)
                }
            }
        }.resume()
    }
    
    /// Logs out the current user by clearing session data
    func logout() {
        userId = nil
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "userId")
    }
    
    // MARK: - User API Methods
    
    /// Fetches the current user's profile information
    func fetchCurrentUser() {
        guard let userId = self.userId else { return }
        fetchUser(withId: userId, retryCount: 3) { [weak self] result in
            switch result {
            case .success(let user):
                self?.currentUser = user
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
                
                // If user not found (404) after retries, handle session expiration
                if let nsError = error as? NSError, nsError.code == 404 {
                    self?.handleSessionExpiration()
                }
            }
        }
    }
    
    /// Handles session expiration by logging the user out
    private func handleSessionExpiration() {
        isLoggedIn = false
        userId = nil
        UserDefaults.standard.removeObject(forKey: "userId")
        errorMessage = "Your session has expired. Please log in again."
    }
    
    /// Fetches a user by their ID with retry functionality
    /// - Parameters:
    ///   - id: The ID of the user to fetch
    ///   - retryCount: Number of retries if the request fails with a 404 or network error
    ///   - completion: Closure called with the result
    func fetchUser(withId id: Int, retryCount: Int = 0, completion: @escaping (Result<User, Error>) -> Void) {
        fetchUserInternal(withId: id, currentRetry: 0, maxRetries: retryCount, completion: completion)
    }
    
    /// Internal implementation of fetchUser with retry functionality
    /// - Parameters:
    ///   - id: The ID of the user to fetch
    ///   - currentRetry: Current retry attempt
    ///   - maxRetries: Maximum number of retry attempts
    ///   - completion: Closure called with the result
    private func fetchUserInternal(withId id: Int, currentRetry: Int, maxRetries: Int, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        let endpoint = "/users/\(id)"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        // Avoid caching issues - always get fresh data
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Keep isLoading true during retries unless it's the last attempt
                if currentRetry >= maxRetries {
                    self.isLoading = false
                }
                
                // Handle network error with retry
                if let error = error {
                    // If we have retries left, try again after a short delay
                    if currentRetry < maxRetries {
                        self.retryFetchUser(id: id, currentRetry: currentRetry, maxRetries: maxRetries, error: error, completion: completion)
                        return
                    }
                    
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    // Handle HTTP error with retry
                    if httpResponse.statusCode == 404 || httpResponse.statusCode >= 500 {
                        // Server error or not found - might be temporary due to database issues
                        if currentRetry < maxRetries {
                            let serverError = NSError(
                                domain: "NetworkManager",
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]
                            )
                            self.retryFetchUser(id: id, currentRetry: currentRetry, maxRetries: maxRetries, error: serverError, completion: completion)
                            return
                        }
                        
                        if httpResponse.statusCode == 404 {
                            // User not found after retries
                            let notFoundError = NSError(
                                domain: "NetworkManager",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "User not found"]
                            )
                            self.errorMessage = "User not found"
                            completion(.failure(notFoundError))
                        } else {
                            // Server error after retries
                            let serverError = NSError(
                                domain: "NetworkManager",
                                code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]
                            )
                            self.errorMessage = "Server error: \(httpResponse.statusCode)"
                            completion(.failure(serverError))
                        }
                        return
                    } else if httpResponse.statusCode != 200 {
                        // Other non-success status codes
                        let serverError = NSError(
                            domain: "NetworkManager",
                            code: httpResponse.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"]
                        )
                        self.errorMessage = "Server error: \(httpResponse.statusCode)"
                        completion(.failure(serverError))
                        return
                    }
                }
                
                guard let data = data else {
                    // No data with retry
                    if currentRetry < maxRetries {
                        let noDataError = NSError(
                            domain: "NetworkManager",
                            code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No data received"]
                        )
                        self.retryFetchUser(id: id, currentRetry: currentRetry, maxRetries: maxRetries, error: noDataError, completion: completion)
                        return
                    }
                    
                    let error = NSError(
                        domain: "NetworkManager",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No data received"]
                    )
                    self.errorMessage = "No data received"
                    completion(.failure(error))
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    self.isLoading = false
                    completion(.success(user))
                } catch {
                    // JSON decoding error with retry
                    if currentRetry < maxRetries {
                        self.retryFetchUser(id: id, currentRetry: currentRetry, maxRetries: maxRetries, error: error, completion: completion)
                        return
                    }
                    
                    self.errorMessage = "Failed to decode user: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Retries fetching a user after a delay
    private func retryFetchUser(id: Int, currentRetry: Int, maxRetries: Int, error: Error, completion: @escaping (Result<User, Error>) -> Void) {
        let retryDelay = Double(currentRetry + 1) * 0.5 // Increasing delay for each retry
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self = self else { return }
            print("Retrying fetchUser (attempt \(currentRetry + 1)/\(maxRetries)) for user ID \(id)")
            self.fetchUserInternal(withId: id, currentRetry: currentRetry + 1, maxRetries: maxRetries, completion: completion)
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
        
        guard let url = URL(string: "\(baseURL)/users/search?term=\(encodedTerm)") else {
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Only set loading to false if this is the last retry attempt
                if currentRetry >= maxRetries {
                    self.isLoading = false
                }
                
                if let error = error {
                    // Network error with retry
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 500 || httpResponse.statusCode == 503 {
                        // Server error with retry
                        if currentRetry < maxRetries {
                            self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                            return
                        }
                        
                        self.errorMessage = "Server error \(httpResponse.statusCode): Unable to fetch users"
                        return
                    } else if httpResponse.statusCode != 200 {
                        // Other HTTP error
                        self.errorMessage = "Server error \(httpResponse.statusCode): Unable to fetch users"
                        return
                    }
                }
                
                guard let data = data else {
                    // No data with retry
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    self.errorMessage = "No data received from server"
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    
                    if !users.isEmpty {
                        self.users = users
                        print("Successfully loaded \(users.count) users")
                    } else if self.users.isEmpty {
                        // If we got an empty array and don't have existing users, retry
                        if currentRetry < maxRetries {
                            print("Received empty users array, retrying...")
                            self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                            return
                        }
                        
                        // Only set empty if we don't already have users and we're out of retries
                        self.users = []
                    }
                } catch {
                    // JSON decoding error with retry
                    if currentRetry < maxRetries {
                        self.retryFetchAllUsers(currentRetry: currentRetry, maxRetries: maxRetries)
                        return
                    }
                    
                    self.errorMessage = "Failed to decode users: \(error.localizedDescription)"
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
    func getConnections(userId: Int) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections") else {
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
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        // User has no connections, clear existing
                        self.connections = []
                        return
                    }
                    
                    if httpResponse.statusCode != 200 {
                        self.errorMessage = "Server error: \(httpResponse.statusCode)"
                        return
                    }
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    self.connections = connections
                } catch {
                    self.errorMessage = "Failed to decode connections: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Adds a connection between two users
    func addConnection(userId: Int, connectionId: Int, relationshipType: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        struct ConnectionRequest: Codable {
            let connectionId: Int
            let relationshipDescription: String
            
            enum CodingKeys: String, CodingKey {
                case connectionId = "connection_id"
                case relationshipDescription = "relationship_description"
            }
        }
        
        let connectionRequest = ConnectionRequest(connectionId: connectionId, relationshipDescription: relationshipType)
        
        guard let jsonData = try? JSONEncoder().encode(connectionRequest) else {
            isLoading = false
            errorMessage = "Failed to encode connection data"
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
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Refresh connections list
                self.getConnections(userId: userId)
                completion(true)
            }
        }.resume()
    }
    
    /// Removes a connection between two users
    func removeConnection(userId: Int, connectionId: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections/\(connectionId)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
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
    
    // MARK: - Helper Methods
    
    /// Handles API errors and executes the completion handler
    private func handleError(_ message: String, error: AuthError, completion: @escaping (Result<Int, AuthError>) -> Void) {
        isLoading = false
        errorMessage = message
        completion(.failure(error))
    }
    
    /// Refreshes all data from the server
    func refreshAll() {
        if let userId = self.userId {
            fetchCurrentUser()
            getConnections(userId: userId)
        }
        fetchAllUsers()
    }
}
