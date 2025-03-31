import SwiftUI

// MARK: - User List Row
struct UserListRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Use UserAvatar component
            UserAvatar(user: user, size: 50)
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let university = user.university {
                        Label(university, systemImage: "building.columns")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let location = user.location {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let jobTitle = user.jobTitle, let company = user.currentCompany {
                    Text("\(jobTitle) at \(company)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let jobTitle = user.jobTitle {
                    Text(jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    UserListRow(user: User(
        id: 1,
        username: "johndoe",
        firstName: "John",
        lastName: "Doe",
        email: "john@example.com",
        phoneNumber: "555-1234",
        location: "New York",
        university: "NYU",
        fieldOfInterest: "Computer Science"
    ))
    .padding()
} 