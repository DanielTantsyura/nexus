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
    
    /// Authentication token for API requests
    private var authToken: String?
    
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
        if let savedUserId = UserDefaults.standard.object(forKey: "userId") as? Int,
           let savedToken = UserDefaults.standard.string(forKey: "authToken") {
            self.userId = savedUserId
            self.authToken = savedToken
            self.isLoggedIn = true
            self.fetchCurrentUser()
        }
    }
    
    /// Saves the user session to UserDefaults
    private func saveSession(userId: Int, token: String) {
        UserDefaults.standard.set(userId, forKey: "userId")
        UserDefaults.standard.set(token, forKey: "authToken")
        self.authToken = token
    }
    
    /// Adds authentication headers to a URLRequest
    private func addAuthHeaders(to request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
    
    /// Handles session expiration
    private func handleSessionExpiration() {
        // Only handle expiration if we're actually logged in
        guard isLoggedIn else { return }
        
        // Try to refresh the token first
        refreshAuthToken { [weak self] success in
            guard let self = self else { return }
            
            if !success {
                // If token refresh fails, clear session and notify user
                DispatchQueue.main.async {
                    self.logout()
                    self.errorMessage = "Your session has expired. Please log in again."
                }
            }
        }
    }
    
    /// Refreshes the authentication token
    private func refreshAuthToken(completion: @escaping (Bool) -> Void) {
        guard let userId = userId, let currentToken = authToken else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/refresh-token") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newToken = json["token"] as? String else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.authToken = newToken
                UserDefaults.standard.set(newToken, forKey: "authToken")
                completion(true)
            }
        }.resume()
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
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
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
                    self.saveSession(userId: loginResponse.userId, token: loginResponse.token)
                    
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
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("Server error updating last login: \(httpResponse.statusCode)")
                return
            }
        }.resume()
    }
    
    /// Logs out the current user by clearing session data
    func logout() {
        userId = nil
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "authToken")
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
    
    /// Fetches a user by their ID with retry functionality
    private func fetchUser(withId id: Int, retryCount: Int = 3, completion: @escaping (Result<User, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(id)") else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        addAuthHeaders(to: &request)
        
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
                    
                case 401:
                    // Token expired, try to refresh
                    self.refreshAuthToken { success in
                        if success && retryCount > 0 {
                            // Retry with new token
                            self.fetchUser(withId: id, retryCount: retryCount - 1, completion: completion)
                        } else {
                            self.handleSessionExpiration()
                            completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired"])))
                        }
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
    /// - Parameters:
    ///   - userId: ID of the user to add the connection to
    ///   - connectionId: ID of the user to connect with (optional, server can determine from text)
    ///   - relationshipType: Description of how the users know each other
    ///   - tags: Optional array of tags to categorize the connection
    ///   - completion: Closure called with success/failure result
    func addConnection(userId: Int, connectionId: Int?, relationshipType: String, tags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections") else {
            handleError("Invalid URL")
            completion(false)
            return
        }
        
        // Prepare request data
        var requestData: [String: Any] = [
            "relationship_type": relationshipType
        ]
        
        if let connectionId = connectionId {
            requestData["connection_id"] = connectionId
        }
        
        if let tags = tags, !tags.isEmpty {
            requestData["tags"] = tags
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
    private func handleError(_ message: String, error: AuthError? = nil, completion: ((Result<Int, AuthError>) -> Void)? = nil) {
        isLoading = false
        errorMessage = message
        if let error = error, let completion = completion {
            completion(.failure(error))
        }
    }
    
    /// Refreshes all data from the server
    func refreshAll() {
        if let userId = self.userId {
            fetchCurrentUser()
            getConnections(userId: userId)
            updateLastLogin()
        }
        fetchAllUsers()
    }
    
    /// Fetches recent tags used by the current user
    /// - Parameter completion: Closure called with result of operation
    func fetchUserRecentTags(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let userId = self.userId else {
            completion(.failure(NSError(domain: "NetworkManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recent-tags") else {
            errorMessage = "Invalid URL"
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let error = NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    let tags = try JSONDecoder().decode([String].self, from: data)
                    completion(.success(tags))
                } catch {
                    self.errorMessage = "Failed to decode recent tags: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
