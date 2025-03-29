import Foundation

struct User: Identifiable, Codable, Hashable {
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
    var gender: String?
    var ethnicity: String?
    var uniMajor: String?
    var jobTitle: String?
    
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
    
    var fullName: String {
        return "\(firstName ?? "Unknown") \(lastName ?? "User")"
    }
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
    }
} 