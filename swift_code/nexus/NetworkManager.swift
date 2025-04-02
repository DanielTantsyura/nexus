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
    
    /// Recent tags for the current user
    @Published var recentTags: [String] = []
    
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
            self.fetchRecentTags()
        }
    }
    
    /// Saves the user session to UserDefaults
    private func saveSession(userId: Int) {
        UserDefaults.standard.set(userId, forKey: "userId")
    }
    
    // MARK: - Authentication Methods
    
    /// Validates user login credentials
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
                    
                    // Update last login timestamp
                    self.updateLastLogin()
                    
                    // If user data is included in the response, use it directly
                    if let user = loginResponse.user {
                        self.currentUser = user
                    } else {
                        self.fetchCurrentUser()
                    }
                    
                    // Fetch recent tags
                    self.fetchRecentTags()
                    
                    completion(.success(loginResponse.userId))
                } catch {
                    self.handleError("Failed to decode login response: \(error.localizedDescription)", 
                                    error: .unknownError, 
                                    completion: completion)
                }
            }
        }.resume()
    }
    
    /// Creates login credentials for a user
    /// - Parameters:
    ///   - userId: The user ID to create credentials for
    ///   - password: The password for the new credentials
    ///   - completion: Closure called with result containing the generated username
    func createLogin(userId: Int, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/login") else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid URL"
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            }
            return
        }
        
        let loginData = CreateLoginRequest(userId: userId, passkey: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to encode login data"
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode login data"])))
            }
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
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let error = NSError(domain: "HTTPError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(statusCode)"])
                    self.errorMessage = "Server error: \(statusCode)"
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.errorMessage = "No data received"
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(CreateLoginResponse.self, from: data)
                    completion(.success(response.username))
                } catch {
                    self.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Updates the last login timestamp for the current user when the app is opened
    func updateLastLogin() {
        guard let userId = self.userId else { return }
        
        guard let url = URL(string: "\(baseURL)/login/update") else {
            print("Invalid URL for updating last login")
            return
        }
        
        let requestData = ["user_id": userId]
        guard let jsonData = try? JSONEncoder().encode(requestData) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
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
    
    /// Fetches all users from the API
    func fetchUsers() {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
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
    
    /// Fetches information about a specific user by ID
    /// - Parameters:
    ///   - userId: The ID of the user to fetch
    ///   - retryCount: Number of retries for this operation
    ///   - completion: Closure called with the result
    func fetchUser(withId userId: Int, retryCount: Int = 0, completion: @escaping (Result<User, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)") else {
            isLoading = false
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    if retryCount > 0 {
                        // Retry after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUser(withId: userId, retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        self.errorMessage = "Network error: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.errorMessage = "Invalid response"
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    let error = NSError(domain: "NetworkError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.errorMessage = "User not found"
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    let error = NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.errorMessage = "No data received"
                    completion(.failure(error))
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    if retryCount > 0 {
                        // Retry after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUser(withId: userId, retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        self.errorMessage = "Failed to decode user: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    /// Searches for users matching the given term
    /// - Parameter term: The search term to look for
    func searchUsers(term: String) {
        isLoading = true
        errorMessage = nil
        
        guard let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/users/search?term=\(encoded)") else { 
            isLoading = false
            errorMessage = "Invalid search term"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
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
                    self.errorMessage = "Failed to decode search results: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Handles session expiration by logging the user out
    private func handleSessionExpiration() {
        isLoggedIn = false
        userId = nil
        UserDefaults.standard.removeObject(forKey: "userId")
        errorMessage = "Your session has expired. Please log in again."
    }
    
    // MARK: - Connection API Methods
    
    /// Fetches connections for the current user
    func fetchUserConnections() {
        guard let userId = self.userId else { return }
        fetchConnections(forUserId: userId)
    }
    
    /// Fetches connections for a specific user
    /// - Parameter userId: The ID of the user to fetch connections for
    func fetchConnections(forUserId userId: Int) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    // Sort connections by last_viewed, placing most recently viewed at the top
                    self.connections = connections.sorted { (conn1, conn2) in
                        guard let lastViewed1 = conn1.lastViewed else { return false }
                        guard let lastViewed2 = conn2.lastViewed else { return true }
                        return lastViewed1 > lastViewed2
                    }
                } catch {
                    self.errorMessage = "Failed to decode connections: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Creates a connection between the current user and another user
    /// - Parameters:
    ///   - contactId: ID of the contact to connect with
    ///   - description: Description of the relationship
    ///   - notes: Optional notes about the connection
    ///   - tags: Optional tags for the connection
    ///   - completion: Closure called when the operation completes
    func createConnection(contactId: Int, description: String, notes: String? = nil, tags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        guard let userId = self.userId else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        var requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId,
            "description": description
        ]
        
        if let notes = notes {
            requestDict["notes"] = notes
        }
        
        if let tags = tags {
            requestDict["tags"] = tags
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
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
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response"
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 201 {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Refresh the connections list
                self.fetchConnections(forUserId: userId)
                completion(true)
            }
        }.resume()
    }
    
    /// Updates an existing connection
    /// - Parameters:
    ///   - contactId: ID of the contact in the connection
    ///   - description: Optional new description
    ///   - notes: Optional new notes
    ///   - tags: Optional new tags
    ///   - completion: Closure called when the operation completes
    func updateConnection(contactId: Int, description: String? = nil, notes: String? = nil, tags: [String]? = nil, completion: @escaping (Bool) -> Void) {
        guard let userId = self.userId else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections/update") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        var requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId
        ]
        
        if let description = description {
            requestDict["description"] = description
        }
        
        if let notes = notes {
            requestDict["notes"] = notes
        }
        
        if let tags = tags {
            requestDict["tags"] = tags
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            isLoading = false
            errorMessage = "Failed to encode connection data"
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
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response"
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Refresh the connections list
                self.fetchConnections(forUserId: userId)
                completion(true)
            }
        }.resume()
    }
    
    /// Updates the last_viewed timestamp for a connection
    /// - Parameters:
    ///   - contactId: ID of the contact in the connection
    ///   - completion: Closure called when the operation completes
    func updateConnectionTimestamp(contactId: Int, completion: @escaping (Bool) -> Void) {
        guard let userId = self.userId else {
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/connections/update") else {
            completion(false)
            return
        }
        
        let requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId,
            "update_timestamp_only": true
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if error != nil || (response as? HTTPURLResponse)?.statusCode != 200 {
                    completion(false)
                    return
                }
                
                // Refresh the connections list if needed
                self?.fetchConnections(forUserId: userId)
                completion(true)
            }
        }.resume()
    }
    
    /// Removes a connection between the current user and another user
    /// - Parameters:
    ///   - contactId: ID of the contact to disconnect from
    ///   - completion: Closure called when the operation completes
    func removeConnection(contactId: Int, completion: @escaping (Bool) -> Void) {
        guard let userId = self.userId else {
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        let requestDict = [
            "user_id": userId,
            "contact_id": contactId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            isLoading = false
            errorMessage = "Failed to encode connection data"
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
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response"
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Update the connections list
                self.connections.removeAll { $0.id == contactId }
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Contact Creation Methods
    
    /// Creates a new contact from free-form text
    /// - Parameters:
    ///   - text: The text description of the contact
    ///   - tags: Optional tags to associate with the contact
    ///   - completion: Closure called when the operation completes
    func createContact(fromText text: String, tags: [String]? = nil, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = self.userId else {
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(.failure(error))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/contacts/create") else {
            isLoading = false
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            errorMessage = "Invalid URL"
            completion(.failure(error))
            return
        }
        
        var requestDict: [String: Any] = [
            "text": text,
            "user_id": userId
        ]
        
        if let tags = tags {
            requestDict["tags"] = tags
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            isLoading = false
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode contact data"])
            errorMessage = "Failed to encode contact data"
            completion(.failure(error))
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
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.errorMessage = "Invalid response"
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode != 201 {
                    let error = NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.errorMessage = "No data received"
                    completion(.failure(error))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let userId = json?["user_id"] as? Int {
                        // If there are tags, update the recent tags
                        if tags != nil && !tags!.isEmpty {
                            self.fetchRecentTags()
                        }
                        // Refresh connections to include the new contact
                        self.fetchUserConnections()
                        completion(.success(userId))
                    } else {
                        let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing user ID in response"])
                        self.errorMessage = "Missing user ID in response"
                        completion(.failure(error))
                    }
                } catch {
                    self.errorMessage = "Failed to parse response: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }.resume()
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
    
    /// Fetches the current user's recent tags
    func fetchRecentTags() {
        guard let userId = self.userId else { return }
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)/recent-tags") else {
            print("Invalid URL for fetching recent tags")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching recent tags: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    print("Server error fetching recent tags: \(httpResponse.statusCode)")
                    return
                }
                
                guard let data = data else {
                    print("No data received for recent tags")
                    return
                }
                
                do {
                    self.recentTags = try JSONDecoder().decode([String].self, from: data)
                } catch {
                    print("Failed to decode recent tags: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Handle API errors and call completion handler
    private func handleError<T>(_ message: String, error: AuthError, completion: @escaping (Result<T, AuthError>) -> Void) {
        isLoading = false
        errorMessage = message
        completion(.failure(error))
    }
    
    /// Refreshes all data from the server
    func refreshAll() {
        if let userId = self.userId {
            fetchCurrentUser()
            fetchConnections(forUserId: userId)
            fetchRecentTags()
            updateLastLogin()
        }
        fetchUsers()
    }
}
