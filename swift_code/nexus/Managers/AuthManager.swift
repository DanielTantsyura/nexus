import SwiftUI
import Combine
import Foundation

class AuthManager {
    private unowned let networkManager: NetworkManager
    
    init(networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    // MARK: - Session Management
    
    /// Restores user session from secure storage if available
    func restoreSession() -> Bool {
        guard let savedUserId = KeychainHelper.shared.get(key: "nexus_user_id") as? Int,
              let sessionExpiry = UserDefaults.standard.object(forKey: "sessionExpiry") as? Date,
              sessionExpiry > Date() else {
            logout()
            return false
        }
        
        // Valid session exists
        networkManager.setUserId(savedUserId)
        networkManager.setLoggedIn(true)
        networkManager.fetchCurrentUser()
        networkManager.fetchRecentTags()
        return true
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
        networkManager.setUserId(nil)
        networkManager.setCurrentUser(nil)
        networkManager.setLoggedIn(false)
        
        // Clear keychain and UserDefaults
        KeychainHelper.shared.delete(key: "nexus_user_id")
        UserDefaults.standard.removeObject(forKey: "sessionExpiry")
        
        // Cancel any pending network requests
        networkManager.cancellables.forEach { $0.cancel() }
        networkManager.cancellables.removeAll()
    }
    
    /// Handles session expiration by logging the user out and notifying UI
    func handleSessionExpiration() {
        // Only handle it once by checking current state
        guard networkManager.isLoggedIn else { return }
        
        // Update state on main thread
        DispatchQueue.main.async {
            // Clear user data
            self.networkManager.setUserId(nil)
            self.networkManager.setCurrentUser(nil)
            self.networkManager.setLoggedIn(false)
            
            // Clear keychain and UserDefaults
            KeychainHelper.shared.delete(key: "nexus_user_id")
            UserDefaults.standard.removeObject(forKey: "sessionExpiry")
            
            // Set error message
            self.networkManager.setErrorMessage("Your session has expired. Please log in again.")
            
            // Cancel any pending network requests
            self.networkManager.cancellables.forEach { $0.cancel() }
            self.networkManager.cancellables.removeAll()
            
            // Post notification for UI to show login screen
            NotificationCenter.default.post(name: Notification.Name("SessionExpired"), object: nil)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Validates user login credentials
    /// - Parameters:
    ///   - username: The user's username
    ///   - password: The user's password
    ///   - completion: Closure called with result of authentication
    func login(username: String, password: String, completion: @escaping (Result<Int, AuthError>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard !username.isEmpty, !password.isEmpty else {
            handleError("Username and password are required", error: .invalidCredentials, completion: completion)
            return
        }
        
        guard let url = URL(string: "\(networkManager.baseURL)/login") else {
            handleError("Invalid URL", error: .unknownError, completion: completion)
            return
        }
        
        guard let jsonData = try? JSONEncoder().encode(Login(username: username, password: password)) else {
            handleError("Failed to encode login data", error: .unknownError, completion: completion)
            return
        }
        
        let request = networkManager.createRequest(for: url, method: "POST", body: jsonData)
        networkManager.cancellables.forEach { $0.cancel() }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AuthError.networkError
                }
                
                switch httpResponse.statusCode {
                case 200...299: return data
                case 401: throw AuthError.invalidCredentials
                case 404: throw AuthError.networkError
                case 429: throw AuthError.tooManyAttempts
                default: throw AuthError.unknownError
                }
            }
            .decode(type: LoginResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionStatus in
                    guard let self = self else { return }
                    self.networkManager.setLoading(false)
                    
                    if case .failure(let error) = completionStatus {
                        let authError = error as? AuthError ?? .unknownError
                        self.networkManager.setErrorMessage(authError.localizedDescription)
                        completion(.failure(authError))
                    }
                },
                receiveValue: { [weak self] loginResponse in
                    guard let self = self else { return }
                    self.networkManager.setLoading(false)
                    self.networkManager.setUserId(loginResponse.userId)
                    self.networkManager.setLoggedIn(true)
                    
                    // Save session and fetch user data
                    self.saveSession(userId: loginResponse.userId)
                    
                    // Update last login timestamp
                    self.updateLastLogin()
                    
                    // Always fetch current user after successful login
                    self.networkManager.fetchCurrentUser()
                    
                    // Fetch recent tags
                    self.networkManager.fetchRecentTags()
                    
                    completion(.success(loginResponse.userId))
                }
            )
            .store(in: &networkManager.cancellables)
    }
    
    /// Updates the last login timestamp for the current user when the app is opened
    func updateLastLogin() {
        guard let userId = networkManager.userId else { return }
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/\(userId)/update-last-login") else {
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
    
    // MARK: - Account Management
    
    /// Creates a new user account with login credentials
    /// - Parameters:
    ///   - userData: Dictionary with user data (first_name, last_name, etc.)
    ///   - username: Username for login
    ///   - password: Password for login
    ///   - completion: Closure called with result containing the new user ID
    func createAccount(userData: [String: Any], username: String, password: String, completion: @escaping (Result<Int, Error>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        // First check if username is available
        checkUsernameAvailability(username) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    self.networkManager.setLoading(false)
                    completion(.failure(self.createError(message: "Username already taken", code: 409, domain: "ValidationError")))
                    return
                }
                
                // Username is available, proceed with account creation
                self.createUser(userData: userData, username: username, password: password, completion: completion)
                
            case .failure(let error):
                self.networkManager.setLoading(false)
                completion(.failure(error))
            }
        }
    }
    
    /// Creates a new user in the database
    /// - Parameters:
    ///   - userData: Dictionary with user data
    ///   - username: Username for login
    ///   - password: Password for login
    ///   - completion: Closure called with result containing the new user ID
    private func createUser(userData: [String: Any], username: String, password: String, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = URL(string: "\(networkManager.baseURL)/people"),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Invalid URL", code: 0)))
            return
        }
        
        components.queryItems = [URLQueryItem(name: "username", value: username)]
        guard let finalUrl = components.url else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Failed to create URL with parameters", code: 0)))
            return
        }
        
        // Prepare request data
        var completeUserData = userData
        completeUserData["password"] = password
        completeUserData["username"] = username
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: completeUserData) else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Failed to encode user data", code: 0)))
            return
        }
        
        // Create and send request
        var request = URLRequest(url: finalUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(username, forHTTPHeaderField: "X-Username")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.networkManager.setLoading(false)
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(self.createError(message: "Invalid response", code: 0)))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    var errorMessage = self.errorMessageForStatusCode(httpResponse.statusCode)
                    
                    // Try to extract error message from response
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let serverError = json["error"] as? String {
                        errorMessage = serverError
                    }
                    
                    completion(.failure(self.createError(message: errorMessage, code: httpResponse.statusCode)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(self.createError(message: "No data received", code: 0)))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let userId = json?["id"] as? Int {
                        completion(.success(userId))
                    } else {
                        completion(.failure(self.createError(message: "User ID not found in response", code: 0)))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    /// Creates login credentials for a user
    func createLogin(userId: Int, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        networkManager.setLoading(true)
        networkManager.setErrorMessage(nil)
        
        guard let url = URL(string: "\(networkManager.baseURL)/login"),
              let jsonData = try? JSONEncoder().encode(CreateLoginRequest(userId: userId, passkey: password)) else {
            networkManager.setLoading(false)
            networkManager.setErrorMessage("Failed to prepare request")
            completion(.failure(createError(message: "Failed to prepare request", code: 0)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.networkManager.setLoading(false)
                
                if let error = error {
                    self.networkManager.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = self.createError(message: "Invalid response", code: 0)
                    self.networkManager.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode), let data = data else {
                    let statusCode = httpResponse.statusCode
                    let error = self.createError(message: self.errorMessageForStatusCode(statusCode), code: statusCode)
                    self.networkManager.setErrorMessage(error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(CreateLoginResponse.self, from: data)
                    completion(.success(response.username))
                } catch {
                    self.networkManager.setErrorMessage("Failed to decode response")
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Checks if a username is available (not already taken)
    func checkUsernameAvailability(_ username: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        networkManager.setLoading(true)
        
        guard let url = URL(string: "\(networkManager.baseURL)/people/username-check?username=\(username)") else {
            networkManager.setLoading(false)
            completion(.failure(createError(message: "Invalid URL", code: 0)))
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.networkManager.setLoading(false)
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(self.createError(message: "Invalid response", code: 0)))
                    return
                }
                
                // If the check endpoint doesn't exist, fall back to search and check if there are results
                if httpResponse.statusCode == 404 {
                    self.searchForUsername(username, completion: completion)
                    return
                }
                
                guard let data = data else {
                    completion(.failure(self.createError(message: "No data received", code: 0)))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let isAvailable = json?["available"] as? Bool ?? false
                    completion(.success(isAvailable))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Fallback method that searches for users with the given username
    private func searchForUsername(_ username: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(networkManager.baseURL)/people/search?q=\(encodedUsername)") else {
            completion(.failure(createError(message: "Invalid URL", code: 0)))
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(self.createError(message: "No data received", code: 0)))
                    return
                }
                
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    // Check if any user has the exact username we're looking for
                    let isUsernameTaken = users.contains { user in
                        user.username?.lowercased() == username.lowercased()
                    }
                    completion(.success(!isUsernameTaken))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a standardized NSError object
    /// - Parameters:
    ///   - message: User-friendly error message
    ///   - code: The error code
    ///   - domain: The error domain (defaults to "NetworkError")
    /// - Returns: NSError with the given parameters
    private func createError(message: String, code: Int, domain: String = "NetworkError") -> NSError {
        return NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    /// Maps HTTP status codes to user-friendly error messages
    /// - Parameter statusCode: HTTP status code from the response
    /// - Returns: User-friendly error message
    private func errorMessageForStatusCode(_ statusCode: Int) -> String {
        switch statusCode {
        case 400: return "Invalid request format"
        case 401: return "Invalid credentials"
        case 403: return "You don't have permission to access this resource"
        case 404: return "Resource not found"
        case 409: return "Username already exists"
        case 429: return "Too many attempts, please try again later"
        case 500, 501, 502, 503: return "Server error, please try again later"
        default: return "An unexpected error occurred (Code: \(statusCode))"
        }
    }
    
    /// Handle API errors and call completion handler
    /// - Parameters:
    ///   - message: The error message to display
    ///   - error: The authentication error
    ///   - completion: The completion handler to call with the failure result
    private func handleError<T>(_ message: String, error: AuthError, completion: @escaping (Result<T, AuthError>) -> Void) {
        networkManager.setLoading(false)
        networkManager.setErrorMessage(message)
        completion(.failure(error))
    }
} 