import Foundation

struct Connection: Identifiable, Codable, Hashable {
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
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Connection, rhs: Connection) -> Bool {
        return lhs.id == rhs.id
    }
} 