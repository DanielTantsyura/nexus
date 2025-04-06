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
    
    /// Queue for synchronized access to shared properties
    private let queue = DispatchQueue(label: "com.nexus.networkmanager", attributes: .concurrent)
    
    /// Set of cancellables for Combine operations
    private var cancellables = Set<AnyCancellable>()
    
    /// Base URL for the API
    private let baseURL: String = {
        // First check if environment variable is set to use local API
        let useLocalApi = ProcessInfo.processInfo.environment["USE_LOCAL_API"]?.lowercased() == "true"
        
        if useLocalApi {
            #if targetEnvironment(simulator)
            return "http://127.0.0.1:8080"
            #else
            // Check if a development server is configured in UserDefaults
            if let devServerIP = UserDefaults.standard.string(forKey: "DevServerIP") {
                return "http://\(devServerIP):8080"
            }
            // Final fallback to localhost via network IP
            return "http://10.0.0.232:8080"
            #endif
        }
        
        // For development/simulator, check if a custom URL is configured
        if let configuredURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? UserDefaults.standard.string(forKey: "ApiBaseUrl") {
            return configuredURL
        }
        
        // Use the correct Railway URL
        return "https://nexus-production-6654.up.railway.app"
    }()
    
    /// Default request timeout in seconds
    private let defaultTimeout: TimeInterval = 30.0
    
    // MARK: - Private Property Accessors with Thread Safety
    
    private func setLoading(_ value: Bool) {
        DispatchQueue.main.async {
            self.isLoading = value
        }
    }
    
    private func setErrorMessage(_ value: String?) {
        DispatchQueue.main.async {
            self.errorMessage = value
        }
    }
    
    private func setUsers(_ value: [User]) {
        DispatchQueue.main.async {
            self.users = value
        }
    }
    
    private func setCurrentUser(_ value: User?) {
        DispatchQueue.main.async {
            self.currentUser = value
        }
    }
    
    private func setConnections(_ value: [Connection]) {
        DispatchQueue.main.async {
            self.connections = value
        }
    }
    
    private func setLoggedIn(_ value: Bool) {
        DispatchQueue.main.async {
            self.isLoggedIn = value
        }
    }
    
    private func setUserId(_ value: Int?) {
        DispatchQueue.main.async {
            self.userId = value
        }
    }
    
    private func setRecentTags(_ value: [String]) {
        DispatchQueue.main.async {
            self.recentTags = value
        }
    }
    
    // MARK: - Initialization
    
    /// Initialize the network manager and restore session if available
    init() {
        let useLocalApi = ProcessInfo.processInfo.environment["USE_LOCAL_API"]?.lowercased() == "true"
        if useLocalApi {
            print("API URL: \(baseURL) (using local API via environment variable)")
        } else {
            print("API URL: \(baseURL) (using hosted Railway API)")
            // Test if the API is accessible
            let testURL = URL(string: "\(baseURL)/diagnostic")
            if let testURL = testURL {
                let task = URLSession.shared.dataTask(with: testURL) { data, response, error in
                    if let error = error {
                        print("API connection test failed: \(error.localizedDescription)")
                    } else if let httpResponse = response as? HTTPURLResponse {
                        print("API connection test status: \(httpResponse.statusCode)")
                        if let data = data, let responseString = String(data: data, encoding: .utf8) {
                            print("API diagnostic response: \(responseString)")
                        }
                    }
                }
                task.resume()
            }
        }
        let _ = restoreSession()
    }
    
    // MARK: - Session Management
    
    /// Restores user session from secure storage if available
    func restoreSession() -> Bool {
        if let savedUserId = KeychainHelper.shared.get(key: "nexus_user_id") as? Int {
            if let sessionExpiry = UserDefaults.standard.object(forKey: "sessionExpiry") as? Date,
               sessionExpiry > Date() {
                // Valid session exists
                self.userId = savedUserId
                self.isLoggedIn = true
                
                // Fetch user data, but handle failure silently
                fetchCurrentUser()
                fetchRecentTags()
                return true
            } else {
                // Session expired - clear it
                logout()
            }
        }
        return false
    }
    
    /// Saves the user session to secure storage
    private func saveSession(userId: Int) {
        // Save user ID to Keychain
        KeychainHelper.shared.save(userId, key: "nexus_user_id")
        
        // Set session expiry (e.g., 30 days from now)
        let expiryDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        UserDefaults.standard.set(expiryDate, forKey: "sessionExpiry")
    }
    
    /// Logs out the current user by clearing session data
    func logout() {
        userId = nil
        currentUser = nil
        isLoggedIn = false
        
        // Clear keychain and UserDefaults
        KeychainHelper.shared.delete(key: "nexus_user_id")
        UserDefaults.standard.removeObject(forKey: "sessionExpiry")
        
        // Cancel any pending network requests
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Authentication Methods
    
    /// Validates user login credentials
    /// - Parameters:
    ///   - username: The user's username
    ///   - password: The user's password
    ///   - completion: Closure called with result of authentication
    func login(username: String, password: String, completion: @escaping (Result<Int, AuthError>) -> Void) {
        setLoading(true)
        setErrorMessage(nil)
        
        guard !username.isEmpty, !password.isEmpty else {
            handleError("Username and password are required", error: .invalidCredentials, completion: completion)
            return
        }
        
        guard let url = URL(string: "\(baseURL)/login") else {
            handleError("Invalid URL", error: .unknownError, completion: completion)
            return
        }
        
        print("Attempting login to: \(url.absoluteString)")
        
        let loginData = Login(username: username, password: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            handleError("Failed to encode login data", error: .unknownError, completion: completion)
            return
        }
        
        let request = createRequest(for: url, method: "POST", body: jsonData)
        
        // Cancel any existing login requests
        cancellables.forEach { cancellable in
            cancellable.cancel()
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Login error: Not an HTTP response")
                    throw AuthError.networkError
                }
                
                print("Login response status code: \(httpResponse.statusCode)")
                
                // Log response body for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Login response body: \(responseString)")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw AuthError.invalidCredentials
                case 404:
                    print("Login error: Endpoint not found (404)")
                    throw AuthError.networkError
                case 429:
                    throw AuthError.tooManyAttempts
                default:
                    print("Login error: Unexpected status code \(httpResponse.statusCode)")
                    throw AuthError.unknownError
                }
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionStatus in
                    guard let self = self else { return }
                    self.setLoading(false)
                    
                    if case .failure(let error) = completionStatus {
                        if let authError = error as? AuthError {
                            self.setErrorMessage(authError.localizedDescription)
                            completion(.failure(authError))
                        } else {
                            self.setErrorMessage(error.localizedDescription)
                            completion(.failure(.unknownError))
                        }
                    }
                },
                receiveValue: { [weak self] loginResponse in
                    guard let self = self else { return }
                    self.setLoading(false)
                    self.setUserId(loginResponse.userId)
                    self.setLoggedIn(true)
                    
                    // Save session and fetch user data
                    self.saveSession(userId: loginResponse.userId)
                    
                    // Update last login timestamp
                    self.updateLastLogin()
                    
                    // Always fetch current user after successful login
                    self.fetchCurrentUser()
                    
                    // Fetch recent tags
                    self.fetchRecentTags()
                    
                    completion(.success(loginResponse.userId))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Creates login credentials for a user
    /// - Parameters:
    ///   - userId: The user ID to create credentials for
    ///   - password: The password for the new credentials (used as passkey in API)
    ///   - completion: Closure called with result containing the generated username
    /// - Note: The API will automatically generate a username based on the user's first and last name.
    ///         The generated username will be returned in the response.
    func createLogin(userId: Int, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/login") else {
            DispatchQueue.main.async {
                self.setLoading(false)
                self.setErrorMessage("Invalid URL")
                completion(.failure(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            }
            return
        }
        
        let loginData = CreateLoginRequest(userId: userId, passkey: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            DispatchQueue.main.async {
                self.setLoading(false)
                self.setErrorMessage("Failed to encode login data")
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
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let error = NSError(domain: "HTTPError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(statusCode)"])
                    self.setErrorMessage("Server error: \(statusCode)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.setErrorMessage("No data received")
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(CreateLoginResponse.self, from: data)
                    completion(.success(response.username))
                } catch {
                    self.setErrorMessage("Failed to decode response: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Updates the last login timestamp for the current user when the app is opened
    func updateLastLogin() {
        guard let userId = self.userId else { return }
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)/update-last-login") else {
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
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    // 404 might mean the login entry doesn't exist yet but user ID is valid
                    // This is not a critical error, so just log it and continue
                    print("Last login update returned 404 - login entry may not exist yet for user ID: \(userId)")
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                print("Server error updating last login: \(httpResponse.statusCode)")
                return
                }
            }
        }.resume()
    }
    
    // MARK: - User API Methods
    
    /// Fetches the current user's profile information
    func fetchCurrentUser() {
        guard let userId = self.userId else { return }
        
        print("Fetching current user with ID: \(userId)")
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)") else {
            print("Invalid URL for current user")
            return
        }
        
        let request = createRequest(for: url)
        
        // Create a publisher for fetching user
        let userPublisher = URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if httpResponse.statusCode == 401 {
                    // Session expired
                    throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired"])
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                }
                
                return data
            }
            .decode(type: User.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
        
        // Cancel any existing subscriptions for this operation
        cancellables.forEach { $0.cancel() }
        
        userPublisher
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Failed to fetch user: \(error.localizedDescription)")
                        
                        // For 401 errors, handle session expiration
                        if let nsError = error as NSError?, nsError.domain == "AuthError" && nsError.code == 401 {
                            self?.handleSessionExpiration()
                            return
                        }
                        
                        // For 404 errors, try a second approach using the /people endpoint
                        if let nsError = error as NSError?, nsError.code == 404 {
                            print("User not found by ID, trying to find in all users list")
                            self?.findUserInAllUsers(userId)
                        }
                    }
                },
                receiveValue: { [weak self] user in
                    print("Successfully fetched user: \(user.id)")
                    self?.setCurrentUser(user)
                    
                    // Once we have the user, fetch connections
                    self?.fetchUserConnections()
                }
            )
            .store(in: &cancellables)
    }
    
    /// Find a user in the all users list when direct fetch fails
    private func findUserInAllUsers(_ targetUserId: Int) {
        // First check if we already have users loaded
        if !users.isEmpty {
            if let foundUser = users.first(where: { $0.id == targetUserId }) {
                print("Found user \(targetUserId) in existing users list")
                self.setCurrentUser(foundUser)
                // Now that we have the user, fetch their connections
                self.fetchUserConnections()
                return
            }
        }
        
        // Otherwise fetch all users and look for the one we need
        print("Fetching all users to find user ID: \(targetUserId)")
        
        guard let url = URL(string: "\(baseURL)/people") else {
            print("Invalid URL for fetching all users")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching all users: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    print("No data received when fetching all users")
                    return
                }
                
                do {
                    let allUsers = try JSONDecoder().decode([User].self, from: data)
                    self.setUsers(allUsers)
                    
                    if let foundUser = allUsers.first(where: { $0.id == targetUserId }) {
                        print("Found user \(targetUserId) in fetched users list")
                        self.setCurrentUser(foundUser)
                        // Now that we have the user, fetch their connections
                        self.fetchUserConnections()
                    } else {
                        print("User \(targetUserId) not found in users list, creating minimal user")
                        // Create a minimal user as last resort
                        let minimalUser = User(
                            id: targetUserId,
                            username: nil,
                            firstName: "User",
                            lastName: "\(targetUserId)",
                            email: nil,
                            phoneNumber: nil,
                            location: nil,
                            university: nil,
                            fieldOfInterest: nil,
                            highSchool: nil,
                            birthday: nil,
                            createdAt: nil,
                            currentCompany: nil,
                            gender: nil,
                            ethnicity: nil,
                            uniMajor: nil,
                            jobTitle: nil,
                            lastLogin: nil,
                            profileImageUrl: nil,
                            linkedinUrl: nil,
                            recentTags: nil
                        )
                        self.setCurrentUser(minimalUser)
                        // Try to fetch connections anyway
                        self.fetchUserConnections()
                    }
                } catch {
                    print("Failed to decode all users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    /// Fetches all users from the API
    func fetchAllUsers() {
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/people") else {
            setLoading(false)
            setErrorMessage("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                    self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                        return
                    }
                    
                guard let data = data else {
                    self.setErrorMessage("No data received")
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self.setUsers(users)
                } catch {
                    self.setErrorMessage("Failed to decode users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    /// Fetches a user by username using the /people/<username> API endpoint
    /// - Parameters:
    ///   - username: The username to look up
    ///   - completion: Closure called with the result
    func fetchUserByUsername(_ username: String, completion: @escaping (Result<User, Error>) -> Void) {
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/people/\(username)") else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        // If we're viewing this user from a logged-in account, add viewing_user_id parameter
        // to trigger the last_viewed timestamp update in the API
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if let currentUserId = self.userId {
            let queryItem = URLQueryItem(name: "viewing_user_id", value: "\(currentUserId)")
            urlComponents?.queryItems = [queryItem]
        }
        
        guard let finalUrl = urlComponents?.url else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: finalUrl) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.setErrorMessage("Invalid response")
                    completion(.failure(error))
                            return
                        }
                        
                        if httpResponse.statusCode == 404 {
                    let error = NSError(domain: "NetworkError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                            self.setErrorMessage("User not found")
                    completion(.failure(error))
                        return
                }
                
                if httpResponse.statusCode != 200 {
                    let error = NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(error))
                        return
                    }
                    
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.setErrorMessage("No data received")
                    completion(.failure(error))
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    completion(.success(user))
                } catch {
                    self.setErrorMessage("Failed to decode user: \(error.localizedDescription)")
                    completion(.failure(error))
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
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)") else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
            guard let self = self else { return }
                self.setLoading(false)
                
                if let error = error {
                    if retryCount > 0 {
                        // Retry after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.fetchUser(withId: userId, retryCount: retryCount - 1, completion: completion)
                        }
                    } else {
                        self.setErrorMessage("Network error: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.setErrorMessage("Invalid response")
                    completion(.failure(error))
            return
        }
        
                if httpResponse.statusCode == 404 {
                    let error = NSError(domain: "NetworkError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
                    self.setErrorMessage("User not found")
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    let error = NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.setErrorMessage("No data received")
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
                        self.setErrorMessage("Failed to decode user: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    /// Searches for users matching the given term
    /// - Parameter term: The search term to look for
    func searchUsers(term: String) {
        setLoading(true)
        setErrorMessage(nil)
        
        // Use proper URLComponents to build the search URL
        guard let baseSearchUrl = URL(string: "\(baseURL)/people/search") else {
            setLoading(false)
            setErrorMessage("Invalid URL")
            return
        }
        
        var components = URLComponents(url: baseSearchUrl, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "term", value: term)]
        
        guard let url = components?.url else {
            setLoading(false)
            setErrorMessage("Invalid search term")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.setErrorMessage("No data received")
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    self.setUsers(users)
                } catch {
                    self.setErrorMessage("Failed to decode search results: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    /// Handles session expiration by logging the user out and notifying UI
    private func handleSessionExpiration() {
        // Only handle it once by checking current state
        guard isLoggedIn else { return }
        
        // Update state on main thread
        DispatchQueue.main.async {
            // Clear user data
            self.setUserId(nil)
            self.setCurrentUser(nil)
            self.setLoggedIn(false)
            
            // Clear keychain and UserDefaults
            KeychainHelper.shared.delete(key: "nexus_user_id")
            UserDefaults.standard.removeObject(forKey: "sessionExpiry")
            
            // Set error message
            self.setErrorMessage("Your session has expired. Please log in again.")
            
            // Cancel any pending network requests
            self.cancellables.forEach { $0.cancel() }
            self.cancellables.removeAll()
            
            // Post notification for UI to show login screen
            NotificationCenter.default.post(name: Notification.Name("SessionExpired"), object: nil)
        }
    }
    
    // MARK: - Connection API Methods
    
    /// Fetches connections for the current user
    func fetchUserConnections() {
        guard let userId = self.userId else { return }
        fetchConnections(forUserId: userId)
    }
    
    /// Extracts tags from connection data in different formats
    /// - Parameter tagsValue: The value from the JSON that might contain tags
    /// - Returns: Array of string tags or nil if not present
    private func extractTags(from tagsValue: Any?) -> [String]? {
        guard let tagsValue = tagsValue else { return nil }
        
        // Case 1: Tags as array of strings
        if let tagsArray = tagsValue as? [String] {
            return tagsArray.filter { !$0.isEmpty }
        }
        
        // Case 2: Tags as comma-separated string
        if let tagsString = tagsValue as? String, !tagsString.isEmpty {
            return tagsString.split(separator: ",")
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
        }
        
        // Case 3: Tags as something else we can convert to string
        let stringValue = String(describing: tagsValue)
                              .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stringValue.isEmpty && stringValue != "Optional(nil)" && stringValue != "(null)" {
            return stringValue.split(separator: ",")
                              .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                              .filter { !$0.isEmpty }
        }
        
        return nil
    }
    
    /// Fetches connections for a specific user
    /// - Parameter userId: The ID of the user to fetch connections for
    func fetchConnections(forUserId userId: Int) {
        setLoading(true)
        setErrorMessage(nil)
        
        print("Fetching connections for user ID: \(userId)")
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)/connections") else {
            setLoading(false)
            print("Invalid URL for fetching connections")
            // Don't set errorMessage to avoid showing to user
            // Initialize with empty connections instead
            setConnections([])
            return
        }
        
        let request = createRequest(for: url)
        
        // Cancel any existing connections fetch
        cancellables.forEach { $0.cancel() }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                // Debug: Print raw JSON response 
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("===== Raw connections API response =====")
                    print(jsonString)
                    print("========================================")
                }
                
                // Handle common status codes
                if httpResponse.statusCode == 404 || httpResponse.statusCode == 204 {
                    // Not an error, just no connections or no content
                    return "[]".data(using: .utf8)!
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                }
                
                // If we get an empty response, return an empty array
                if data.isEmpty {
                    return "[]".data(using: .utf8)!
                }
                
                return data
            }
            .tryMap { [weak self] data -> [Connection] in
                guard let self = self else { return [] }
                
                // Handle empty data
                if data.count <= 2 { // Just "[]" or similar
                    return []
                }
                
                // First try standard decoding
                if let connections = try? JSONDecoder().decode([Connection].self, from: data) {
                    return connections
                }
                
                // If that fails, try manual decoding with tag extraction
                do {
                    guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                        print("Failed to parse JSON array for connections")
                        return []
                    }
                    
                    return jsonArray.compactMap { connectionDict -> Connection? in
                        // Extract tags using our helper method
                        let tags = self.extractTags(from: connectionDict["tags"])
                        
                        // Remove tags from the dictionary to avoid double processing
                        var mutableDict = connectionDict
                        mutableDict.removeValue(forKey: "tags")
                        
                        // Convert dictionary to JSON data
                        guard let jsonData = try? JSONSerialization.data(withJSONObject: mutableDict) else {
                            return nil
                        }
                        
                        // Try to decode the connection
                        guard var connection = try? JSONDecoder().decode(Connection.self, from: jsonData) else {
                            return nil
                        }
                        
                        // Set the extracted tags
                        connection.tags = tags
                        
                        return connection
                    }
                } catch {
                    print("Error parsing connections: \(error.localizedDescription)")
                    return []
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.setLoading(false)
                    
                    if case let .failure(error) = completion {
                        print("Failed to fetch connections: \(error.localizedDescription)")
                        self.setConnections([])
                    }
                },
                receiveValue: { [weak self] connections in
                    guard let self = self else { return }
                    
                    // Sort connections by last_viewed, placing most recently viewed at the top
                    let sortedConnections = connections.sorted { (conn1, conn2) in
                        guard let lastViewed1 = conn1.lastViewed else { return false }
                        guard let lastViewed2 = conn2.lastViewed else { return true }
                        return lastViewed1 > lastViewed2
                    }
                    
                    self.setConnections(sortedConnections)
                    print("Fetched \(sortedConnections.count) connections")
                }
            )
            .store(in: &cancellables)
    }
    
    /// Creates a connection between the current user and another user
    /// - Parameters:
    ///   - contactId: ID of the contact to connect with
    ///   - description: Description of the relationship
    ///   - notes: Optional notes about the connection
    ///   - tags: Optional tags for the connection
    ///   - completion: Closure called when the operation completes
    func createConnection(contactId: Int, description: String, notes: String? = nil, tags: [String]? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = self.userId else {
            let error = NSError(domain: "NetworkError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(.failure(error))
            return
        }
        
        // Input validation
        guard contactId > 0 else {
            let error = NSError(domain: "ValidationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid contact ID"])
            completion(.failure(error))
            return
        }
        
        guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let error = NSError(domain: "ValidationError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Description cannot be empty"])
            completion(.failure(error))
            return
        }
        
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            setErrorMessage("Invalid URL")
            completion(.failure(error))
            return
        }
        
        var requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId,
            "relationship_type": description
        ]
        
        if let notes = notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestDict["notes"] = notes
        }
        
        if let tags = tags, !tags.isEmpty {
            // Filter out empty tags
            let validTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                              .filter { !$0.isEmpty }
            if !validTags.isEmpty {
                requestDict["tags"] = validTags
            }
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to encode connection data"])
            setErrorMessage("Failed to encode connection data")
            completion(.failure(error))
            return
        }
        
        let request = createRequest(for: url, method: "POST", body: jsonData)
        
        // Cancel any existing connection operations
        cancellables.forEach { $0.cancel() }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                guard httpResponse.statusCode == 201 else {
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                }
                
                return true
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionStatus in
                    guard let self = self else { return }
                    self.setLoading(false)
                    
                    if case let .failure(error) = completionStatus {
                        self.setErrorMessage(error.localizedDescription)
                        completion(.failure(error))
                    }
                },
                receiveValue: { [weak self] success in
                    guard let self = self else { return }
                    
                    // Refresh the connections list
                    self.fetchConnections(forUserId: userId)
                    
                    // Update recent tags if needed
                    if tags != nil, !tags!.isEmpty {
                        self.fetchRecentTags()
                    }
                    
                    completion(.success(success))
                }
            )
            .store(in: &cancellables)
    }
    
    /// Updates an existing connection
    /// - Parameters:
    ///   - contactId: ID of the contact in the connection
    ///   - description: Optional new description
    ///   - notes: Optional new notes
    ///   - tags: Optional new tags
    ///   - updateTimestampOnly: If true, only update the last_viewed timestamp without modifying other fields
    ///   - completion: Closure called when the operation completes
    func updateConnection(contactId: Int, description: String? = nil, notes: String? = nil, 
                         tags: [String]? = nil, updateTimestampOnly: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let userId = self.userId else {
            completion(false)
            return
        }
        
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            setLoading(false)
            setErrorMessage("Invalid URL")
            completion(false)
            return
        }
        
        var requestDict: [String: Any] = [
            "user_id": userId,
            "contact_id": contactId
        ]
        
        if updateTimestampOnly {
            // API supports update_timestamp_only parameter to only update the last_viewed timestamp
            requestDict["update_timestamp_only"] = true
        } else {
            // Only include these fields if we're doing a full update
            if let description = description {
                requestDict["relationship_type"] = description
            }
            
            if let notes = notes {
                requestDict["notes"] = notes  // Use "notes" to match actual database column name
            }
            
            if let tags = tags {
                // The tags need to be a simple comma-separated string for the database
                requestDict["tags"] = tags.joined(separator: ",")
            }
        }
        
        print("Updating connection with data: \(requestDict)")
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            setLoading(false)
            setErrorMessage("Failed to encode connection data")
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
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    print("Failed to update connection: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.setErrorMessage("Invalid response")
                    print("Invalid response when updating connection")
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    print("Server error when updating connection: \(httpResponse.statusCode)")
                    
                    // Print response body for debugging
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Response body: \(responseString)")
                    }
                    
                    completion(false)
                    return
                }
                
                print("Successfully updated connection")
                
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
                
        guard let url = URL(string: "\(baseURL)/connections") else {
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
        
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/connections") else {
            setLoading(false)
            setErrorMessage("Invalid URL")
            completion(false)
            return
        }
        
        let requestDict = [
            "user_id": userId,
            "contact_id": contactId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestDict) else {
            setLoading(false)
            setErrorMessage("Failed to encode connection data")
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
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.setErrorMessage("Invalid response")
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                // Update the connections list
                self.setConnections(self.connections.filter { $0.id != contactId })
                completion(true)
            }
        }.resume()
    }
    
    /// Deletes a contact by removing the connection between users
    /// - Parameters:
    ///   - contactId: ID of the contact to delete
    ///   - completion: Closure called when the operation completes with success status
    func deleteContact(contactId: Int, completion: @escaping (Bool) -> Void) {
        // Use the existing removeConnection method since deletion is the same operation
        removeConnection(contactId: contactId, completion: completion)
    }
    
    // MARK: - Contact Creation Methods
    
    /// Creates a new contact from free-form text
    /// - Parameters:
    ///   - text: The text description of the contact - should contain information that the API can parse
    ///           like name, contact info, etc. This is processed by the API's newUser.create_new_contact
    ///   - tags: Optional tags to associate with the contact
    ///   - completion: Closure called when the operation completes
    func createContact(fromText text: String, tags: [String]? = nil, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let userId = self.userId else {
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
            completion(.failure(error))
            return
        }
        
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/contacts/create") else {
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            setErrorMessage("Invalid URL")
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
            setLoading(false)
            let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode contact data"])
            setErrorMessage("Failed to encode contact data")
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
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    self.setErrorMessage("Invalid response")
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode != 201 {
                    let error = NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    self.setErrorMessage("No data received")
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
                        self.setErrorMessage("Missing user ID in response")
                        completion(.failure(error))
                    }
                } catch {
                    self.setErrorMessage("Failed to parse response: \(error.localizedDescription)")
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
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)/recent-tags") else {
            setErrorMessage("Invalid URL")
            completion(.failure(NSError(domain: "NetworkManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    let error = NSError(domain: "NetworkManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    self.setErrorMessage("No data received")
                    completion(.failure(NSError(domain: "NetworkManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }
                
                do {
                    // First try to decode as an array of strings
                    let tags = try? JSONDecoder().decode([String].self, from: data)
                    if let tags = tags {
                        print("Successfully fetched \(tags.count) recent tags as array")
                        self.setRecentTags(tags)
                        return
                    }
                    
                    // If that fails, try as a single string and split it
                    let tagsString = try? JSONDecoder().decode(String.self, from: data)
                    if let tagsString = tagsString, !tagsString.isEmpty {
                        print("Fetched recent tags as string: \(tagsString)")
                        let tagArray = tagsString.split(separator: ",").map { String($0) }
                        self.setRecentTags(tagArray)
                        print("Split into \(tagArray.count) tags")
                        return
                    }
                    
                    // If both fail, try as custom JSON format
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let json = json, let tagsValue = json["recent_tags"] {
                        if let tagsArray = tagsValue as? [String] {
                            print("Fetched \(tagsArray.count) tags from JSON object")
                            self.setRecentTags(tagsArray)
                        } else if let tagsString = tagsValue as? String, !tagsString.isEmpty {
                            let tagArray = tagsString.split(separator: ",").map { String($0) }
                            self.setRecentTags(tagArray)
                            print("Split JSON string into \(tagArray.count) tags")
                        } else {
                            print("Tags value has unknown format")
                            self.setRecentTags([])
                        }
                    } else {
                        print("Could not parse tags JSON")
                        self.setRecentTags([])
                    }
                } catch {
                    print("Failed to decode recent tags: \(error.localizedDescription)")
                    // Initialize with empty array instead of failing
                    self.setRecentTags([])
                }
            }
        }.resume()
    }
    
    /// Fetches the current user's recent tags
    func fetchRecentTags() {
        guard let userId = self.userId else { return }
        
        isLoading = true
        print("Fetching recent tags for user ID: \(userId)")
        
        guard let url = URL(string: "\(baseURL)/people/\(userId)/recent-tags") else {
            print("Invalid URL for recent tags")
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching recent tags: \(error.localizedDescription)")
                    // Initialize with empty array instead of failing
                    self.setRecentTags([])
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 404 {
                        print("Recent tags not found for user ID: \(userId) - this is not critical")
                        // Initialize with empty array instead of failing
                        self.setRecentTags([])
                        return
                    }
                    
                    if !(200...299).contains(httpResponse.statusCode) {
                        print("Server error fetching recent tags: \(httpResponse.statusCode)")
                        // Initialize with empty array instead of failing
                        self.setRecentTags([])
                        return
                    }
                }
                
                guard let data = data else {
                    print("No data received for recent tags")
                    self.setRecentTags([])
                    return
                }
                
                do {
                    // First try to decode as an array of strings
                    let tags = try? JSONDecoder().decode([String].self, from: data)
                    if let tags = tags {
                        print("Successfully fetched \(tags.count) recent tags as array")
                        self.setRecentTags(tags)
                        return
                    }
                    
                    // If that fails, try as a single string and split it
                    let tagsString = try? JSONDecoder().decode(String.self, from: data)
                    if let tagsString = tagsString, !tagsString.isEmpty {
                        print("Fetched recent tags as string: \(tagsString)")
                        let tagArray = tagsString.split(separator: ",").map { String($0) }
                        self.setRecentTags(tagArray)
                        print("Split into \(tagArray.count) tags")
                        return
                    }
                    
                    // If both fail, try as custom JSON format
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let json = json, let tagsValue = json["recent_tags"] {
                        if let tagsArray = tagsValue as? [String] {
                            print("Fetched \(tagsArray.count) tags from JSON object")
                            self.setRecentTags(tagsArray)
                        } else if let tagsString = tagsValue as? String, !tagsString.isEmpty {
                            let tagArray = tagsString.split(separator: ",").map { String($0) }
                            self.setRecentTags(tagArray)
                            print("Split JSON string into \(tagArray.count) tags")
                        } else {
                            print("Tags value has unknown format")
                            self.setRecentTags([])
                        }
                    } else {
                        print("Could not parse tags JSON")
                        self.setRecentTags([])
                    }
                } catch {
                    print("Failed to decode recent tags: \(error.localizedDescription)")
                    // Initialize with empty array instead of failing
                    self.setRecentTags([])
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a URLRequest with standard configuration
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - method: HTTP method (default is GET)
    ///   - body: Optional body data
    ///   - timeout: Optional custom timeout (uses default if not specified)
    /// - Returns: A configured URLRequest
    private func createRequest(for url: URL, 
                               method: String = "GET", 
                               body: Data? = nil,
                               timeout: TimeInterval? = nil) -> URLRequest {
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
    
    /// Handle API errors and call completion handler
    private func handleError<T>(_ message: String, error: AuthError, completion: @escaping (Result<T, AuthError>) -> Void) {
        setLoading(false)
        setErrorMessage(message)
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
        fetchAllUsers()
    }
    
    /// Updates a user with the given data dictionary
    /// - Parameters:
    ///   - userId: ID of the user to update
    ///   - userData: Dictionary of user fields to update
    ///   - completion: Callback with success status
    func updateUser(userId: Int, userData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/people/\(userId)") else {
            setErrorMessage("Invalid URL")
            completion(false)
            return
        }
        
        isLoading = true
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userData)
            request.httpBody = jsonData
        } catch {
            isLoading = false
            setErrorMessage("Failed to encode user data: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        // If we're updating the current user, refresh the data
                        if userId == self.userId {
                            self.fetchCurrentUser()
                        }
                        completion(true)
                    } else {
                        self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                        completion(false)
                    }
                } else {
                    self.setErrorMessage("Invalid response")
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// Updates a user with the given User object
    /// - Parameters:
    ///   - user: User object with updated fields
    ///   - completion: Callback with success status
    func updateUser(_ user: User, completion: @escaping (Bool) -> Void) {
        setLoading(true)
        setErrorMessage(nil)
        
        guard let url = URL(string: "\(baseURL)/people/\(user.id)") else {
            setLoading(false)
            setErrorMessage("Invalid URL")
            completion(false)
            return
        }
        
        // Create a dictionary of the user properties to send only what's changed
        // This follows the API's expectation to receive only changed fields
        var userDict: [String: Any] = [:]
        
        if let firstName = user.firstName {
            userDict["first_name"] = firstName
        }
        
        if let lastName = user.lastName {
            userDict["last_name"] = lastName
        }
        
        if let email = user.email {
            userDict["email"] = email
        }
        
        if let phoneNumber = user.phoneNumber {
            userDict["phone_number"] = phoneNumber
        }
        
        if let location = user.location {
            userDict["location"] = location
        }
        
        if let university = user.university {
            userDict["university"] = university
        }
        
        if let fieldOfInterest = user.fieldOfInterest {
            userDict["field_of_interest"] = fieldOfInterest
        }
        
        if let highSchool = user.highSchool {
            userDict["high_school"] = highSchool
        }
        
        if let birthday = user.birthday {
            userDict["birthday"] = birthday
        }
        
        if let currentCompany = user.currentCompany {
            userDict["current_company"] = currentCompany
        }
        
        if let gender = user.gender {
            userDict["gender"] = gender
        }
        
        if let ethnicity = user.ethnicity {
            userDict["ethnicity"] = ethnicity
        }
        
        if let uniMajor = user.uniMajor {
            userDict["uni_major"] = uniMajor
        }
        
        if let jobTitle = user.jobTitle {
            userDict["job_title"] = jobTitle
        }
        
        if let profileImageUrl = user.profileImageUrl {
            userDict["profile_image_url"] = profileImageUrl
        }
        
        if let linkedinUrl = user.linkedinUrl {
            userDict["linkedin_url"] = linkedinUrl
        }
        
        if let recentTags = user.recentTags {
            userDict["recent_tags"] = recentTags.joined(separator: ",")
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userDict) else {
            setLoading(false)
            setErrorMessage("Failed to encode user data")
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
                self.setLoading(false)
                
                if let error = error {
                    self.setErrorMessage("Network error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.setErrorMessage("Invalid response")
                    completion(false)
                    return
                }
                
                if !(200...299).contains(httpResponse.statusCode) {
                    self.setErrorMessage("Server error: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                // If updating the current user, refresh the current user data
                if user.id == self.userId {
                    self.setCurrentUser(user)
                    self.fetchCurrentUser() // Refresh from server to get any server-side changes
                }
                
                completion(true)
            }
        }.resume()
    }
    
    /// Extension to Publishers to add retry with exponential backoff
    private func networkPublisher<T>(_ publisher: AnyPublisher<T, Error>, maxRetries: Int = 3) -> AnyPublisher<T, Error> {
        return publisher
            .retry(maxRetries)
            .timeout(.seconds(defaultTimeout), scheduler: DispatchQueue.main)
            .handleEvents(
                receiveSubscription: { [weak self] _ in
                    self?.setLoading(true)
                },
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.setErrorMessage(error.localizedDescription)
                    }
                    self?.setLoading(false)
                },
                receiveCancel: { [weak self] in
                    self?.setLoading(false)
                }
            )
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher for a network request with standard error handling and retries
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - type: The expected return type
    ///   - maxRetries: Maximum number of retries (default is 3)
    /// - Returns: A publisher with the decoded response
    private func createNetworkPublisher<T: Decodable>(for request: URLRequest, type: T.Type, maxRetries: Int = 3) -> AnyPublisher<T, Error> {
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                }
                
                if httpResponse.statusCode == 401 {
                    // Session expired
                    self.handleSessionExpiration()
                    throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired"])
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NSError(domain: "NetworkError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(httpResponse.statusCode)"])
                }
                
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .retry(maxRetries)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}