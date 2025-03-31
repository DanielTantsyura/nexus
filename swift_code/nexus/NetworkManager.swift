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
        
        isLoading = true
        errorMessage = nil
        
        let endpoint = "/users/\(userId)"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
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
                    let user = try JSONDecoder().decode(User.self, from: data)
                    self.currentUser = user
                } catch {
                    self.errorMessage = "Failed to decode user: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Fetches all users from the API
    func fetchUsers() {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users", type: [User].self) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let users):
                self.users = users
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Searches for users matching the given search term
    /// - Parameter term: The search term to find users by
    func searchUsers(term: String) {
        guard !term.isEmpty else {
            fetchUsers()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        guard let encodedTerm = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            errorMessage = "Invalid search term"
            isLoading = false
            return
        }
        
        fetchData("/users/search?term=\(encodedTerm)", type: [User].self) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let users):
                self.users = users
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Fetches a specific user by username
    /// - Parameter username: The username to fetch
    func getUser(username: String) {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users/\(username)", type: User.self) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            switch result {
            case .success(let user):
                self.selectedUser = user
                self.getConnections(userId: user.id)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Connection API Methods
    
    /// Fetches connections for a specific user
    /// - Parameter userId: The ID of the user whose connections to fetch
    func getConnections(userId: Int) {
        isLoading = true
        // Don't clear connections here, it can cause UI flicker
        // Only clear them if we get an error or empty result
        errorMessage = nil
        
        let endpoint = "/users/\(userId)/connections"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            connections = []
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.connections = []
                    self.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    self.connections = []
                    self.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    self.connections = []
                    self.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    
                    // Force UI update by setting to empty first if there are connections
                    if !connections.isEmpty {
                        // This trick helps force a UI update
                        self.connections = []
                        // Then a tiny delay before setting actual connections
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.connections = connections
                        }
                    } else {
                        // Just set to empty if there are no connections
                        self.connections = []
                    }
                } catch let error {
                    self.errorMessage = "JSON decoding error: \(error.localizedDescription)"
                    self.connections = []
                    self.scheduleConnectionRetry(userId: userId)
                }
            }
        }.resume()
    }
    
    /// Adds a new connection between two users
    /// - Parameters:
    ///   - userId: The ID of the first user
    ///   - connectionId: The ID of the user to connect with
    ///   - relationshipType: Description of the relationship
    ///   - completion: Closure called when operation completes, with success flag
    func addConnection(userId: Int, connectionId: Int, relationshipType: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            handleRequestError("Invalid URL", completion: completion)
            return
        }
        
        let connectionData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId,
            "description": relationshipType
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionData) else {
            handleRequestError("Failed to encode connection data", completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        performRequestWithCompletion(request: request, userId: userId, completion: completion)
    }
    
    /// Removes a connection between two users
    /// - Parameters:
    ///   - userId: The ID of the first user
    ///   - connectionId: The ID of the connection to remove
    ///   - completion: Closure called when operation completes, with success flag
    func removeConnection(userId: Int, connectionId: Int, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            handleRequestError("Invalid URL", completion: completion)
            return
        }
        
        let connectionData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionData) else {
            handleRequestError("Failed to encode connection data", completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        performRequestWithCompletion(request: request, userId: userId, completion: completion)
    }
    
    // MARK: - Profile Update
    
    /// Updates a user's profile information
    /// - Parameters:
    ///   - userId: The ID of the user to update
    ///   - userData: Dictionary of user data to update
    ///   - completion: Closure called when operation completes, with success flag
    func updateUserProfile(userId: Int, userData: [String: Any], completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)") else {
            handleRequestError("Invalid URL", completion: completion)
            return
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userData) else {
            handleRequestError("Failed to encode user data", completion: completion)
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
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    let errorMsg = self.extractErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                    self.errorMessage = errorMsg
                    completion(false)
                    return
                }
                
                // Refresh the current user data
                self.fetchCurrentUser()
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Generic method to fetch and decode data from the API
    /// - Parameters:
    ///   - endpoint: API endpoint to fetch from
    ///   - type: The type to decode the response into
    ///   - completion: Closure called with the result
    private func fetchData<T: Decodable>(_ endpoint: String, type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(URLError(.zeroByteResource)))
                    return
                }
                
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Schedules a retry for fetching connections after a delay
    /// - Parameter userId: The ID of the user whose connections to retry fetching
    private func scheduleConnectionRetry(userId: Int) {
        // Retry after a slightly longer delay to avoid overwhelming the server
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.retryGetConnections(userId: userId)
        }
    }
    
    /// Retries the connection fetch operation
    /// - Parameter userId: The ID of the user whose connections to fetch
    private func retryGetConnections(userId: Int) {
        let endpoint = "/users/\(userId)/connections"
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Connection retry failed: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    self.connections = connections
                } catch let error {
                    self.errorMessage = "Failed to decode connections: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    /// Handles login errors and calls the completion handler
    /// - Parameters:
    ///   - message: Error message to display
    ///   - error: The type of authentication error
    ///   - completion: Completion handler to call with the error
    private func handleError(_ message: String, error: AuthError, completion: @escaping (Result<Int, AuthError>) -> Void) {
        isLoading = false
        errorMessage = message
        completion(.failure(error))
    }
    
    /// Handles request errors for operations with completion handlers
    /// - Parameters:
    ///   - message: Error message to display
    ///   - completion: Completion handler to call with false
    private func handleRequestError(_ message: String, completion: @escaping (Bool) -> Void) {
        isLoading = false
        errorMessage = message
        completion(false)
    }
    
    /// Extracts error message from response data if possible
    /// - Parameter data: Response data that might contain an error message
    /// - Returns: Extracted error message or nil
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data,
              let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorMessage = errorJson["error"] as? String else {
            return nil
        }
        return "Server error: \(errorMessage)"
    }
    
    /// Performs a request with a completion handler, handling common response processing
    /// - Parameters:
    ///   - request: The URLRequest to perform
    ///   - userId: User ID for refreshing connections after success
    ///   - completion: Completion handler to call with the result
    private func performRequestWithCompletion(request: URLRequest, userId: Int, completion: @escaping (Bool) -> Void) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse,
                   !(200...299).contains(httpResponse.statusCode) {
                    let errorMsg = self.extractErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                    self.errorMessage = errorMsg
                    completion(false)
                    return
                }
                
                // Refresh connections after successful operation
                self.getConnections(userId: userId)
                completion(true)
            }
        }.resume()
    }
}
