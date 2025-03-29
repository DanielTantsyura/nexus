import SwiftUI
import Combine

// MARK: - Models
struct User: Identifiable, Codable {
    var id: Int
    var username: String?
    var firstName: String?
    var lastName: String?
    var email: String?
    var phoneNumber: String?
    var location: String?
    var university: String?
    var fieldOfInterest: String?
    var highSchool: String?
    var birthday: String?
    var createdAt: String?
    var currentCompany: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
        case location
        case university
        case fieldOfInterest = "field_of_interest"
        case highSchool = "high_school"
        case birthday
        case createdAt = "created_at"
        case currentCompany = "current_company"
    }
    
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
}

struct Connection: Identifiable, Codable {
    var id: Int
    var username: String?
    var firstName: String?
    var lastName: String?
    var email: String?
    var phoneNumber: String?
    var location: String?
    var university: String?
    var fieldOfInterest: String?
    var highSchool: String?
    var relationshipDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case phoneNumber = "phone_number"
        case location
        case university
        case fieldOfInterest = "field_of_interest"
        case highSchool = "high_school"
        case relationshipDescription = "relationship_description"
    }
    
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
}

// MARK: - Network Manager (combines ViewModel and Service)
class NetworkManager: ObservableObject {
    @Published var users: [User] = []
    @Published var selectedUser: User?
    @Published var connections: [Connection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Use localhost for simulator, IP address for physical device
    #if targetEnvironment(simulator)
    private let baseURL = "http://127.0.0.1:8080"  // Explicitly use IPv4 localhost
    #else
    // Replace with your Mac's actual IP address when testing on a physical device
    private let baseURL = "http://10.0.0.232:8080"
    #endif
    
    // MARK: - API Methods
    func fetchUsers() {
        isLoading = true
        errorMessage = nil
        
        fetchData("/users", type: [User].self) { [weak self] result in
            self?.isLoading = false
            
            switch result {
            case .success(let users):
                self?.users = users
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
                print("Error fetching users: \(error.localizedDescription)")
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
    
    func getConnections(userId: Int) {
        fetchData("/users/\(userId)/connections", type: [Connection].self) { [weak self] result in
            switch result {
            case .success(let connections):
                self?.connections = connections
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
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
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP status code: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("No data received from API")
                    completion(.failure(URLError(.zeroByteResource)))
                    return
                }
                
                // Print the raw JSON string for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON data: \(jsonString.prefix(200))...")
                }
                
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decodedData))
                } catch {
                    print("JSON decoding error: \(error)")
                    // Try to get more detailed decoding error information
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("Key '\(key)' not found: \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch for type '\(type)': \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("Value not found for type '\(type)': \(context.debugDescription)")
                        case .dataCorrupted(let context):
                            print("Data corrupted: \(context.debugDescription)")
                        @unknown default:
                            print("Unknown decoding error")
                        }
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
