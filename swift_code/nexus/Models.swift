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
    
    /// Profile image URL
    let profileImageUrl: String?
    
    /// LinkedIn profile URL
    let linkedinUrl: String?
    
    /// Recent tags used by the user - stored as a comma-separated string in the database
    private let _recentTagsString: String?
    
    /// Recent tags used by the user - converted to array
    var recentTags: [String]? {
        guard let tagsString = _recentTagsString, !tagsString.isEmpty else {
            return nil
        }
        return tagsString.split(separator: ",").map { String($0) }
    }
    
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
        case profileImageUrl = "profile_image_url"
        case linkedinUrl = "linkedin_url"
        case _recentTagsString = "recent_tags"
    }
    
    // MARK: - Init
    
    /// Custom initializer that allows setting all properties
    init(id: Int, username: String?, firstName: String?, lastName: String?, email: String?, phoneNumber: String?, location: String?, university: String?, fieldOfInterest: String?, highSchool: String?, birthday: String?, createdAt: String?, currentCompany: String?, gender: String?, ethnicity: String?, uniMajor: String?, jobTitle: String?, lastLogin: String?, profileImageUrl: String?, linkedinUrl: String?, recentTags: [String]?) {
        self.id = id
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phoneNumber = phoneNumber
        self.location = location
        self.university = university
        self.fieldOfInterest = fieldOfInterest
        self.highSchool = highSchool
        self.birthday = birthday
        self.createdAt = createdAt
        self.currentCompany = currentCompany
        self.gender = gender
        self.ethnicity = ethnicity
        self.uniMajor = uniMajor
        self.jobTitle = jobTitle
        self.lastLogin = lastLogin
        self.profileImageUrl = profileImageUrl
        self.linkedinUrl = linkedinUrl
        self._recentTagsString = recentTags?.joined(separator: ",")
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
    
    /// Unique identifier for the connection (contact's user ID)
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
    
    /// Current company of the connected user
    let currentCompany: String?
    
    /// Profile image URL of the connected user
    let profileImageUrl: String?
    
    /// LinkedIn profile URL of the connected user
    let linkedinUrl: String?
    
    /// Notes about the connection
    let notes: String?
    
    /// Tags associated with the connection - may be stored as string or array
    private var _tagsString: String?
    
    /// Tags stored as an array after processing
    var tags: [String]? {
        get {
            guard let tagsStr = _tagsString, !tagsStr.isEmpty else {
                return nil
            }
            return tagsStr.split(separator: ",").map { String($0) }
        }
        set {
            _tagsString = newValue?.joined(separator: ",")
        }
    }
    
    /// When the connection was last viewed
    let lastViewed: String?
    
    /// User object created from connection data
    var user: User {
        return User(
            id: id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            location: location,
            university: university,
            fieldOfInterest: fieldOfInterest,
            highSchool: highSchool,
            birthday: nil,
            createdAt: nil,
            currentCompany: currentCompany,
            gender: gender,
            ethnicity: ethnicity,
            uniMajor: uniMajor,
            jobTitle: jobTitle,
            lastLogin: nil,
            profileImageUrl: profileImageUrl,
            linkedinUrl: linkedinUrl,
            recentTags: nil
        )
    }
    
    /// Formatted last contact date string
    var lastContactFormat: String {
        guard let lastViewed = lastViewed else { return "Never" }
        
        // Simple date formatting
        if lastViewed.isEmpty { return "Never" }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = dateFormatter.date(from: lastViewed) else {
            return "Unknown"
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        
        return displayFormatter.string(from: date)
    }
    
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
        case relationshipDescription = "relationship_description"
        case gender
        case ethnicity
        case uniMajor = "uni_major"
        case jobTitle = "job_title"
        case currentCompany = "current_company"
        case profileImageUrl = "profile_image_url"
        case linkedinUrl = "linkedin_url"
        case notes = "custom_note"
        case _tagsString = "tags"
        case lastViewed = "last_viewed"
    }
    
    // MARK: - Computed Properties
    
    /// Returns the full name of the connected user
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
    
    /// Returns the contact's ID (same as id in this API)
    var contactId: Int {
        return id
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
    
    /// Password for authentication
    let password: String
}

/// Request to create new login credentials
struct CreateLoginRequest: Codable {
    /// User ID to create login for
    let userId: Int
    
    /// Password or passkey for authentication
    let passkey: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "people_id"
        case passkey
    }
}

/// Response from login creation
struct CreateLoginResponse: Codable {
    /// Whether the operation was successful
    let success: Bool
    
    /// Generated username
    let username: String
}

/// Response from a successful login
struct LoginResponse: Codable {
    /// ID of the authenticated user
    let userId: Int
    
    /// Last login timestamp (can be nil for first-time login)
    let lastLogin: String?
    
    /// Username returned from login
    let username: String?
    
    /// Maps Swift property names to JSON field names
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case lastLogin = "last_login"
        case username = "username"
    }
    
    // Custom initializer to handle different response formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // userId is required - if it's missing, decoding will fail
        userId = try container.decode(Int.self, forKey: .userId)
        
        // These are optional fields
        lastLogin = try container.decodeIfPresent(String.self, forKey: .lastLogin)
        username = try container.decodeIfPresent(String.self, forKey: .username)
    }
}

// MARK: - Error Enums

/// Authentication errors that can occur during login/logout
enum AuthError: Error {
    case invalidCredentials
    case networkError
    case unknownError
    case tooManyAttempts
    
    var localizedDescription: String {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        case .tooManyAttempts:
            return "Too many login attempts. Please try again later."
        }
    }
} 