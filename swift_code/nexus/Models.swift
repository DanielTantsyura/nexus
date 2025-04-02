import Foundation

// MARK: - Data Models

/// Represents a user in the Nexus application
struct User: Identifiable, Codable, Hashable {
    // MARK: - Properties
    
    /// Unique identifier for the user
    let id: Int
    
    /// Username for login
    let username: String?
    
    /// User's first name
    let firstName: String?
    
    /// User's last name
    let lastName: String?
    
    /// User's email address
    let email: String?
    
    /// User's phone number
    let phoneNumber: String?
    
    /// User's location (city, country)
    let location: String?
    
    /// University or college attended
    let university: String?
    
    /// User's professional or personal interests
    let fieldOfInterest: String?
    
    /// High school attended
    let highSchool: String?
    
    /// User's birthday
    let birthday: String?
    
    /// Account creation date
    let createdAt: String?
    
    /// Current company or employer
    let currentCompany: String?
    
    /// User's gender
    let gender: String?
    
    /// User's ethnicity
    let ethnicity: String?
    
    /// University major or field of study
    let uniMajor: String?
    
    /// Current job title
    let jobTitle: String?
    
    /// Last login timestamp
    let lastLogin: String?
    
    // MARK: - Coding Keys
    
    /// Maps Swift property names to JSON field names
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
        case gender
        case ethnicity
        case uniMajor = "uni_major"
        case jobTitle = "job_title"
        case lastLogin = "last_login"
    }
    
    // MARK: - Computed Properties
    
    /// Returns the full name of the user
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
    
    // MARK: - Hashable Conformance
    
    /// Hashes the user based on its ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Compares two users based on their IDs
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Represents a connection between users (similar to a Contact)
struct Connection: Identifiable, Codable, Hashable {
    // MARK: - Properties
    
    /// Unique identifier for the connection (user ID)
    let id: Int
    
    /// Username of the connected user
    let username: String?
    
    /// First name of the connected user
    let firstName: String?
    
    /// Last name of the connected user
    let lastName: String?
    
    /// Email of the connected user
    let email: String?
    
    /// Phone number of the connected user
    let phoneNumber: String?
    
    /// Location of the connected user
    let location: String?
    
    /// University of the connected user
    let university: String?
    
    /// Professional or personal interests of the connected user
    let fieldOfInterest: String?
    
    /// High school of the connected user
    let highSchool: String?
    
    /// Type of relationship with this connection
    let relationshipType: String?
    
    /// Notes about the relationship
    let note: String?
    
    /// Tags for the connection
    let tags: String?
    
    /// When the connection was last viewed
    let lastViewed: String?
    
    /// Gender of the connected user
    let gender: String?
    
    /// Ethnicity of the connected user
    let ethnicity: String?
    
    /// University major of the connected user
    let uniMajor: String?
    
    /// Job title of the connected user
    let jobTitle: String?
    
    // MARK: - Coding Keys
    
    /// Maps Swift property names to JSON field names
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
        case relationshipType = "relationship_type"
        case note
        case tags
        case lastViewed = "last_viewed"
        case gender
        case ethnicity
        case uniMajor = "uni_major"
        case jobTitle = "job_title"
    }
    
    // MARK: - Computed Properties
    
    /// Returns the full name of the connected user
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
    
    /// Returns a description of the relationship with additional context
    var relationshipDescription: String? {
        if let type = relationshipType, !type.isEmpty {
            if let note = note, !note.isEmpty {
                return "\(type) • \(note)"
            }
            return type.capitalized
        }
        return nil
    }
    
    // MARK: - Hashable Conformance
    
    /// Hashes the connection based on its ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Compares two connections based on their IDs
    static func == (lhs: Connection, rhs: Connection) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Authentication Models

/// Model for authentication data
struct Login: Codable {
    let username: String
    let password: String
}

/// Model for authentication response
struct LoginResponse: Codable {
    let status: String
    let userId: Int
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case status
        case userId = "user_id"
        case user
    }
}

/// Error types for authentication
enum AuthError: Error {
    case invalidCredentials
    case networkError
    case unknownError
} 