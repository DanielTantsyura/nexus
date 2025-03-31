import Foundation

// MARK: - Data Models

/// Represents a user in the Nexus application
struct User: Identifiable, Codable, Hashable {
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
    }
    
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
    
    /// Description of the relationship with this connection
    let relationshipDescription: String?
    
    /// Gender of the connected user
    let gender: String?
    
    /// Ethnicity of the connected user
    let ethnicity: String?
    
    /// University major of the connected user
    let uniMajor: String?
    
    /// Job title of the connected user
    let jobTitle: String?
    
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
        case relationshipDescription = "relationship_description"
        case gender
        case ethnicity
        case uniMajor = "uni_major"
        case jobTitle = "job_title"
    }
    
    /// Returns the full name of the connected user
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
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

/// Login request payload
struct Login: Codable {
    /// Username for authentication
    let username: String
    
    /// Password or passkey for authentication
    let passkey: String
}

/// Response from a successful login
struct LoginResponse: Codable {
    /// ID of the authenticated user
    let userId: Int
    
    /// Maps Swift property names to JSON field names
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}

/// Errors that can occur during authentication
enum AuthError: Error {
    /// Invalid username or password
    case invalidCredentials
    
    /// Network connectivity issues
    case networkError
    
    /// Other unspecified errors
    case unknownError
    
    /// Human-readable error message
    var message: String {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError:
            return "Network error. Please check your connection"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
} 