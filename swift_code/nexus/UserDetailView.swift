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
                // User info section with tags
                userInfoSection
                
                // Notes section (if any)
                if let relationship = relationship, let notes = relationship.notes {
                    notesSection(notes: notes)
                }
                
                // Combined relationship description and contact information
                combinedInfoSection
            }
            .padding()
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingEditContactSheet = true }) {
                    Image(systemName: "square.and.pencil")
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
                
                // Tags displayed directly under header
                if let relationship = relationship, let tags = relationship.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tagColor(for: tag).opacity(0.2))
                                    .foregroundColor(tagColor(for: tag))
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.top, 4)
                }
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
                
                // Job title and company with building icon
                if let jobTitle = user.jobTitle, let company = user.currentCompany {
                    HStack {
                        Text(jobTitle)
                            .fontWeight(.bold) // Bold job title
                            .font(.subheadline) // Make job title smaller
                            .foregroundColor(.gray) // Make job title gray
                        Image(systemName: "building.2.fill") // Light blue work building icon
                            .foregroundColor(Color.blue.opacity(0.5)) // Light blue icon
                        Text(company)
                            .foregroundColor(.gray) // Make company gray
                    }
                } else if let jobTitle = user.jobTitle {
                    Text(jobTitle)
                        .fontWeight(.bold) // Bold job title
                        .font(.subheadline) // Make job title smaller
                        .foregroundColor(.gray) // Make job title gray
                } else if let company = user.currentCompany {
                    HStack {
                        Image(systemName: "building.2.fill") // Light blue work building icon
                            .foregroundColor(Color.blue.opacity(0.5)) // Light blue icon
                        Text(company)
                            .foregroundColor(.gray) // Make company gray
                    }
                }
                
                // Education and location on the third line
                HStack {
                    if let university = user.university {
                        Image(systemName: "graduationcap.fill") // Light blue university icon
                            .foregroundColor(Color.blue.opacity(0.5)) // Light blue icon
                        Text(university)
                            .font(.subheadline) // Make university text smaller
                            .foregroundColor(.gray)
                    }
                    if let location = user.location {
                        Image(systemName: "location.fill") // Blue location icon
                            .foregroundColor(.blue) // Blue icon
                        Text(location)
                            .font(.subheadline) // Make location text smaller
                            .foregroundColor(.gray)
                    }
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
    
    // New sections to add
    
    private func tagsSection(tags: [String]) -> some View {
        SectionCard(title: "Tags") {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagBadge(text: tag, showRemoveButton: false)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func notesSection(notes: String) -> some View {
        SectionCard(title: "Notes") {
            Text(notes)
                .padding(.vertical, 8)
        }
    }
    
    // New combined section for relationship description and contact info
    private var combinedInfoSection: some View {
        SectionCard(title: "Contact Information") {
            VStack(alignment: .leading, spacing: 12) {
                // Relationship description first (if available)
                if let relationship = relationship, let description = relationship.relationshipDescription {
                    InfoRow(icon: "person.2.fill", title: "Relationship Description", value: description)
                }
                
                // Divider only if both description and contact info exist
                if (relationship?.relationshipDescription != nil) && 
                   (user.email != nil || user.phoneNumber != nil) {
                    Divider()
                        .padding(.vertical, 4)
                }
                
                // Contact information
                if let email = user.email {
                    InfoRow(icon: "envelope.fill", title: "Email", value: email)
                }
                
                if let phone = user.phoneNumber {
                    InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                }
                
                // Add edit button at the bottom of the section
                Button(action: {
                    showingEditContactSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.pencil")
                        Text("Edit Contact")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
            }
            .padding(.vertical, 4)
        }
    }
    
    // Color function to match NetworkView tag coloring
    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
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