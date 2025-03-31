import SwiftUI
import Combine
import Foundation

// MARK: - Network Manager 
class NetworkManager: ObservableObject {
    // MARK: - Published Properties
    @Published var users: [User] = []
    @Published var selectedUser: User?
    @Published var currentUser: User?
    @Published var connections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    @Published var userId: Int? = nil
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // Use localhost for simulator, IP address for physical device
    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8080"  // Explicitly use IPv4 localhost
    #else
    // Replace with your Mac's actual IP address when testing on a physical device
    private let baseURL = "http://10.0.0.232:8080"
    #endif
    
    // MARK: - Init
    init() {
        // Load saved user ID from UserDefaults if available
        if let savedUserId = UserDefaults.standard.object(forKey: "userId") as? Int {
            self.userId = savedUserId
            self.isLoggedIn = true
            // Fetch current user details
            self.fetchCurrentUser()
        }
    }
    
    // MARK: - Auth Methods
    func login(username: String, password: String, completion: @escaping (Result<Int, AuthError>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/login/validate") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(.failure(.unknownError))
            return
        }
        
        let loginData = Login(username: username, passkey: password)
        
        guard let jsonData = try? JSONEncoder().encode(loginData) else {
            isLoading = false
            errorMessage = "Failed to encode login data"
            completion(.failure(.unknownError))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(.networkError))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        self?.errorMessage = "Invalid username or password"
                        completion(.failure(.invalidCredentials))
                        return
                    }
                    
                    if !(200...299).contains(httpResponse.statusCode) {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        completion(.failure(.unknownError))
                        return
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    completion(.failure(.networkError))
                    return
                }
                
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    self?.userId = loginResponse.userId
                    self?.isLoggedIn = true
                    
                    // Save the user ID to UserDefaults
                    UserDefaults.standard.set(loginResponse.userId, forKey: "userId")
                    
                    // Fetch current user details
                    self?.fetchCurrentUser()
                    
                    completion(.success(loginResponse.userId))
                } catch {
                    self?.errorMessage = "Failed to decode login response: \(error.localizedDescription)"
                    completion(.failure(.unknownError))
                }
            }
        }.resume()
    }
    
    func logout() {
        // Clear user data
        userId = nil
        currentUser = nil
        isLoggedIn = false
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "userId")
    }
    
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
        
        print("Fetching current user with ID: \(userId)")
        
        // Set cache policy to reload to avoid caching issues
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Network error fetching user: \(error.localizedDescription)")
                    return
                }
                
                // Check for HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode != 200 {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        print("HTTP error fetching user: \(httpResponse.statusCode)")
                        return
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    print("No data received when fetching user")
                    return
                }
                
                do {
                    let user = try JSONDecoder().decode(User.self, from: data)
                    print("Successfully decoded user: \(user.fullName)")
                    self?.currentUser = user
                } catch {
                    self?.errorMessage = "Failed to decode user: \(error.localizedDescription)"
                    print("JSON decoding error: \(error)")
                    
                    // Log the received data for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw response data: \(jsonString)")
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - User API Methods
    func fetchUsers() {
        print("Fetching all users")
        isLoading = true
        errorMessage = nil
        
        fetchData("/users", type: [User].self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let users):
                print("Received \(users.count) users")
                self?.users = users
            case .failure(let error):
                print("Error fetching users: \(error.localizedDescription)")
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
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
            self?.isLoading = false
            
            switch result {
            case .success(let users):
                self?.users = users
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
    
    func getUser(username: String) {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users/\(username)", type: User.self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let user):
                self?.selectedUser = user
                self?.getConnections(userId: user.id)
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
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
            // Clear connections if error
            connections = []
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    // Clear connections if error
                    self?.connections = []
                    self?.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        // Clear connections if error
                        self?.connections = []
                        self?.scheduleConnectionRetry(userId: userId)
                        return
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    // Clear connections if no data
                    self?.connections = []
                    self?.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    
                    // Force UI update by setting to empty first if there are connections
                    if !connections.isEmpty {
                        DispatchQueue.main.async {
                            // This trick helps force a UI update
                            self?.connections = []
                            // Then a tiny delay before setting actual connections
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self?.connections = connections
                            }
                        }
                    } else {
                        // Just set to empty if there are no connections
                        self?.connections = []
                    }
                } catch let error {
                    self?.errorMessage = "JSON decoding error: \(error.localizedDescription)"
                    // Clear connections if error
                    self?.connections = []
                    self?.scheduleConnectionRetry(userId: userId)
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
            errorMessage = "Invalid URL"
            isLoading = false
            completion(false)
            return
        }
        
        let connectionData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId,
            "description": relationshipType
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionData) else {
            errorMessage = "Failed to encode connection data"
            isLoading = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let success = (200...299).contains(httpResponse.statusCode)
                    if !success {
                        if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMessage = errorJson["error"] as? String {
                            self?.errorMessage = "Server error: \(errorMessage)"
                        } else {
                            self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        }
                        completion(false)
                        return
                    }
                }
                
                // Refresh connections after successful addition
                self?.getConnections(userId: userId)
                completion(true)
            }
        }.resume()
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
            errorMessage = "Invalid URL"
            isLoading = false
            completion(false)
            return
        }
        
        let connectionData: [String: Any] = [
            "user_id": userId,
            "contact_id": connectionId
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: connectionData) else {
            errorMessage = "Failed to encode connection data"
            isLoading = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let success = (200...299).contains(httpResponse.statusCode)
                    if !success {
                        if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMessage = errorJson["error"] as? String {
                            self?.errorMessage = "Server error: \(errorMessage)"
                        } else {
                            self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        }
                        completion(false)
                        return
                    }
                }
                
                // Refresh connections after successful removal
                self?.getConnections(userId: userId)
                completion(true)
            }
        }.resume()
    }
    
    // MARK: - Helper Methods
    private func fetchData<T: Decodable>(_ endpoint: String, type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        print("Fetching data from: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("No data received from API")
                    completion(.failure(URLError(.zeroByteResource)))
                    return
                }
                
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    print("JSON decoding error: \(error)")
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
                if let error = error {
                    self?.errorMessage = "Connection retry failed: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        return
                    }
                }
                
                guard let data = data else {
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    self?.connections = connections
                } catch let error {
                    self?.errorMessage = "Failed to decode connections: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    // MARK: - Update Profile
    func updateUserProfile(userId: Int, userData: [String: Any], completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: "\(baseURL)/users/\(userId)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            completion(false)
            return
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: userData) else {
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
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    let success = (200...299).contains(httpResponse.statusCode)
                    if !success {
                        if let data = data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorMessage = errorJson["error"] as? String {
                            self?.errorMessage = "Server error: \(errorMessage)"
                        } else {
                            self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        }
                        completion(false)
                        return
                    }
                }
                
                // Refresh the current user data
                self?.fetchCurrentUser()
                completion(true)
            }
        }.resume()
    }
}
