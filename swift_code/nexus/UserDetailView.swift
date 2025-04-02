import SwiftUI

/// Displays detailed information about a user including their profile and relationship data
struct UserDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let user: User
    
    // MARK: - State
    @State private var showingEditContactSheet = false
    @State private var relationship: Connection?
    @State private var isLoadingRelationship = true
    @State private var relationshipError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section
                userInfoSection
                
                // Relationship section (if any)
                relationshipSection
            }
            .padding()
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditContactSheet = true }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .onAppear {
            coordinator.activeScreen = .userDetail
            loadRelationship()
            updateLastViewed()
        }
        .sheet(isPresented: $showingEditContactSheet) {
            EditProfileView(user: user)
        }
    }
    
    // MARK: - Subviews
    
    /// Displays user profile information including personal details and education/work history
    private var userInfoSection: some View {
        SectionCard(title: "") {
            VStack(alignment: .leading, spacing: 16) {
                // Header with name and basic info
                userHeaderView
                
                Divider()
                
                // Personal details
                personalDetailsSection
                
                Divider()
                
                // Education and work
                educationWorkSection
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture { showingEditContactSheet = true }
    }
    
    /// Header with user's basic information
    private var userHeaderView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let jobTitle = user.jobTitle, let company = user.currentCompany {
                    Text("\(jobTitle) at \(company)")
                        .font(.headline)
                        .foregroundColor(.blue)
                } else if let jobTitle = user.jobTitle {
                    Text(jobTitle)
                        .font(.headline)
                        .foregroundColor(.blue)
                } else if let company = user.currentCompany {
                    Text("Works at \(company)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                if let location = user.location {
                    Label(location, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            UserAvatar(user: user, size: 80)
        }
        .padding(.bottom, 8)
    }
    
    /// User's personal details section
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Details")
                .font(.headline)
                .padding(.vertical, 4)
            
            Group {
                if let gender = user.gender {
                    InfoRow(icon: "person.fill", title: "Gender", value: gender)
                }
                
                if let ethnicity = user.ethnicity {
                    InfoRow(icon: "person.2.fill", title: "Ethnicity", value: ethnicity)
                }
                
                if let email = user.email {
                    InfoRow(icon: "envelope.fill", title: "Email", value: email)
                }
                
                if let phone = user.phoneNumber {
                    InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                }
            }
        }
    }
    
    /// User's education and work section
    private var educationWorkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Education & Work")
                .font(.headline)
                .padding(.vertical, 4)
            
            Group {
                if let university = user.university {
                    InfoRow(icon: "building.columns.fill", title: "University", value: university)
                }
                
                if let major = user.uniMajor {
                    InfoRow(icon: "book.fill", title: "Major", value: major)
                }
                
                if let highSchool = user.highSchool {
                    InfoRow(icon: "graduationcap.fill", title: "High School", value: highSchool)
                }
                
                if let interests = user.fieldOfInterest {
                    InfoRow(icon: "star.fill", title: "Interests", value: interests)
                }
            }
        }
    }
    
    /// Displays the relationship information between the current user and this user
    private var relationshipSection: some View {
        Group {
            if isLoadingRelationship {
                SectionCard(title: "Relationship") {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                }
            } else if let error = relationshipError {
                SectionCard(title: "Relationship") {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            } else if let relationship = relationship {
                SectionCard(title: "Relationship") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let description = relationship.relationshipDescription {
                            InfoRow(icon: "person.2.fill", title: "Description", value: description)
                        }
                        
                        if let notes = relationship.notes {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(notes)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 4)
                            }
                        }
                        
                        if let tags = relationship.tags, !tags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tags")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(tags, id: \.self) { tag in
                                        TagBadge(text: tag, showRemoveButton: false)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            showingEditContactSheet = true
                        }) {
                            Text("Edit Relationship")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // No relationship exists
                SectionCard(title: "Relationship") {
                    VStack(spacing: 16) {
                        Text("You're not connected with this person yet.")
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            // Show form to add connection
                            showingEditContactSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Connection")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load relationship data between current user and this user
    private func loadRelationship() {
        guard let currentUserId = coordinator.networkManager.userId else { return }
        guard currentUserId != user.id else { return } // Don't load relationship with self
        
        isLoadingRelationship = true
        relationshipError = nil
        
        // First fetch all connections for the current user
        coordinator.networkManager.fetchConnections(forUserId: currentUserId)
        
        // Give time for the fetch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Find the connection to this user if it exists
            self.relationship = coordinator.networkManager.connections.first { $0.id == self.user.id }
            self.isLoadingRelationship = false
        }
    }
    
    /// Update the last viewed timestamp of this connection
    private func updateLastViewed() {
        guard let currentUserId = coordinator.networkManager.userId else { return }
        guard currentUserId != user.id else { return } // Don't update for self
        
        coordinator.networkManager.updateConnectionTimestamp(contactId: user.id) { _ in
            // Success or failure doesn't matter much here
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        UserDetailView(user: User(
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
            lastLogin: nil,
            profileImageUrl: nil,
            linkedinUrl: nil,
            recentTags: nil
        ))
        .environmentObject(AppCoordinator())
    }
} 