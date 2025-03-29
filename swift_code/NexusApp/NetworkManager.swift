import SwiftUI
import Combine

// MARK: - Models
struct User: Identifiable, Codable {
    var id: Int
    var username: String
    var firstName: String
    var lastName: String
    var email: String
    var phoneNumber: String
    var location: String
    var university: String
    var fieldOfInterest: String
    var highSchool: String
    
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
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
    }
}

struct Connection: Identifiable, Codable {
    var id: Int
    var username: String
    var firstName: String
    var lastName: String
    var relationshipDescription: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case relationshipDescription = "relationship_description"
    }
    
    var fullName: String {
        return "\(firstName) \(lastName)"
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
    private let baseURL = "http://localhost:5000"
    
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
                if let userId = user.id as? Int {
                    self?.getConnections(userId: userId)
                }
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
}
