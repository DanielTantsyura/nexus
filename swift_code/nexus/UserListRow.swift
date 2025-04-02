import SwiftUI

// MARK: - User List Row

/// A row component that displays user information in a list
struct UserListRow: View {
    /// User model to display
    let user: User
    
    @State private var showingEditContactSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            UserAvatar(user: user, size: 50)
            
            // User details
            userInfoView
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onLongPressGesture {
            showingEditContactSheet = true
        }
        .sheet(isPresented: $showingEditContactSheet) {
            EditProfileView(user: user)
        }
    }
    
    /// User information display including name, education, location, and job
    private var userInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Full name
            Text(user.fullName)
                .font(.headline)
            
            // Education and location
            educationAndLocationView
            
            // Job information
            jobInformationView
        }
    }
    
    /// Education and location information with icons
    private var educationAndLocationView: some View {
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
    }
    
    /// Job title and company information
    @ViewBuilder
    private var jobInformationView: some View {
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
        fieldOfInterest: "Computer Science",
        highSchool: nil,
        birthday: nil,
        createdAt: nil,
        currentCompany: "Apple Inc.",
        gender: nil,
        ethnicity: nil,
        uniMajor: "Computer Science",
        jobTitle: "iOS Developer",
        lastLogin: nil
    ))
    .padding()
} 