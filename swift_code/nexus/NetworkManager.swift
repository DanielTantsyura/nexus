import SwiftUI
import Combine
import Foundation

// MARK: - Network Manager 
class NetworkManager: ObservableObject {
    // MARK: - Published Properties
    @Published var users: [User] = []
    @Published var selectedUser: User?
    @Published var connections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // Use localhost for simulator, IP address for physical device
    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8080"  // Explicitly use IPv4 localhost
    #else
    // Replace with your Mac's actual IP address when testing on a physical device
    private let baseURL = "http://10.0.0.232:8080"
    #endif
    
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
    func getConnections(userId: Int) {
        print("Fetching connections for user ID: \(userId)")
        isLoading = true
        connections = []
        errorMessage = nil
        
        let endpoint = "/users/\(userId)/connections"
        
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("Network error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    self?.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    guard (200...299).contains(httpResponse.statusCode) else {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                        self?.scheduleConnectionRetry(userId: userId)
                        return
                    }
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    self?.scheduleConnectionRetry(userId: userId)
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    print("Successfully decoded \(connections.count) connections")
                    self?.connections = connections
                } catch {
                    print("JSON decoding error: \(error)")
                    self?.errorMessage = "JSON decoding error: \(error.localizedDescription)"
                    self?.scheduleConnectionRetry(userId: userId)
                }
            }
        }.resume()
    }
    
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
    
    private func scheduleConnectionRetry(userId: Int) {
        // Retry after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.retryGetConnections(userId: userId)
        }
    }
    
    private func retryGetConnections(userId: Int) {
        print("Retrying connection fetch for user ID: \(userId)")
        
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
                
                guard let data = data else {
                    return
                }
                
                do {
                    let connections = try JSONDecoder().decode([Connection].self, from: data)
                    print("Retry successful: \(connections.count) connections")
                    self?.connections = connections
                } catch {
                    self?.errorMessage = "Failed to decode connections: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
