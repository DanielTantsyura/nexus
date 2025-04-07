import SwiftUI

/// Displays detailed information about a user including their profile and relationship data
struct ContactView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // MARK: - State
    
    // Keep the incoming user around just in case
    let initialUser: User
    
    // Actual mutable copy SwiftUI will watch
    @State private var user: User
    
    @State private var isEditing = false
    @State private var relationship: Connection?
    @State private var isLoadingRelationship = true
    @State private var relationshipError: String?
    @State private var refreshTrigger = false
    
    // Editing state variables
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var editJobTitle = ""
    @State private var editCompany = ""
    @State private var editUniversity = ""
    @State private var editUniMajor = ""
    @State private var editLocation = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editGender = ""
    @State private var editEthnicity = ""
    @State private var editInterests = ""
    @State private var editHighSchool = ""
    @State private var editNotes = ""
    
    // Add state for confirmation dialog
    @State private var showDeleteConfirmation = false
    
    // init lets us set up that @State copy
    init(user: User) {
        self.initialUser = user
        self._user = State(initialValue: user)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section with tags
                userInfoSection
                    .id("info-section-\(refreshTrigger)")
                
                // Notes section (if any)
                if let relationship = relationship, let notes = relationship.notes {
                    notesSection(notes: notes)
                        .id("notes-section-\(refreshTrigger)")
                }
                
                // Combined relationship description and contact information
                combinedInfoSection
                    .id("combined-section-\(refreshTrigger)")
            }
            .padding()
        }
        .id("contact-view-\(refreshTrigger)") // Force entire view to refresh when data changes
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button(action: { saveChanges() }) {
                        Image(systemName: "checkmark")
                    }
                } else {
                    Button(action: { startEditing() }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .onAppear {
            coordinator.activeScreen = .contact
            loadRelationship()
            updateLastViewed()
        }
        .confirmationDialog(
            "Delete Contact",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteContact()
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
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
        .onLongPressGesture { startEditing() }
    }
    
    /// Header with user's basic information
    private var userHeaderView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    HStack {
                        TextField("First Name", text: $editFirstName)
                            .font(.title2)
                            .fontWeight(.bold)
                        TextField("Last Name", text: $editLastName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Job title field and company on same row
                    HStack(spacing: 8) {
                        TextField("Job Title", text: $editJobTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        // Company icon and field
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.6))
                            TextField("Company", text: $editCompany)
                                .font(.subheadline)
                        }
                    }
                    
                    // University and location fields
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.7))
                            TextField("University", text: $editUniversity)
                                .font(.subheadline)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            TextField("Location", text: $editLocation)
                                .font(.subheadline)
                        }
                    }
                } else {
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
                if isEditing {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gender")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Gender", text: $editGender)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ethnicity")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Ethnicity", text: $editEthnicity)
                        }
                    }
                } else {
                    if let gender = user.gender {
                        InfoRow(icon: "person.fill", title: "Gender", value: gender)
                    }
                
                    if let ethnicity = user.ethnicity {
                        InfoRow(icon: "person.2.fill", title: "Ethnicity", value: ethnicity)
                    }
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
                if isEditing {
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("University")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("University", text: $editUniversity)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Major")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Major", text: $editUniMajor)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("High School")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("High School", text: $editHighSchool)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interests")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Interests", text: $editInterests)
                        }
                    }
                } else {
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
    }
    
    
    
    /// Load relationship data between current user and this user
    private func loadRelationship() {
        guard let currentUserId = coordinator.networkManager.userId else { return }
        guard currentUserId != user.id else { return } // Don't load relationship with self
        
        print("Loading relationship for current user ID: \(currentUserId) and contact ID: \(user.id)")
        
        isLoadingRelationship = true
        relationshipError = nil
        
        // First fetch all connections for the current user
        coordinator.networkManager.fetchConnections(forUserId: currentUserId)
        
        // Give time for the fetch to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Find the connection to this user if it exists
            // In the API response, the id field is actually the contact's ID
            self.relationship = self.coordinator.networkManager.connections.first { connection in
                return connection.id == self.user.id
            }
            
            if let relationship = self.relationship {
                print("Found relationship: id=\(relationship.id), notes=\(relationship.notes ?? "nil"), tags=\(relationship.tags?.joined(separator: ",") ?? "nil")")
            } else {
                print("No relationship found between user \(currentUserId) and contact \(self.user.id)")
            }
            
            self.isLoadingRelationship = false
            self.refreshTrigger.toggle() // Force UI refresh when relationship data loads
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
            if isEditing {
                VStack(alignment: .leading) {
                    Text("Notes about this contact")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.vertical, 8)
            } else {
                Text(notes)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
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
                if isEditing {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Email", text: $editEmail)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            TextField("Phone", text: $editPhone)
                        }
                    }
                    
                    // Edit buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            saveChanges()
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                    .imageScale(.small)
                                Text("Save")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PrimaryButtonStyle(backgroundColor: .green))
                        .scaleEffect(0.9)
                        
                        Button(action: {
                            cancelEditing()
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                    .imageScale(.small)
                                Text("Cancel")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PrimaryButtonStyle(backgroundColor: .red))
                        .scaleEffect(0.9)
                    }
                    .padding(.top, 10)
                    
                    // Delete contact button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .imageScale(.small)
                            Text("Delete Contact")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(PrimaryButtonStyle(backgroundColor: .red))
                    .scaleEffect(0.9)
                    .padding(.top, 8)
                } else {
                    if let email = user.email {
                        InfoRow(icon: "envelope.fill", title: "Email", value: email)
                    }
                
                    if let phone = user.phoneNumber {
                        InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                    }
                
                    // Add edit button at the bottom of the section
                    Button(action: {
                        startEditing()
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Edit Contact")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Edit Mode Methods
    
    /// Initialize edit mode with current user data
    private func startEditing() {
        editFirstName = user.firstName ?? ""
        editLastName = user.lastName ?? ""
        editJobTitle = user.jobTitle ?? ""
        editCompany = user.currentCompany ?? ""
        editUniversity = user.university ?? ""
        editUniMajor = user.uniMajor ?? ""
        editLocation = user.location ?? ""
        editEmail = user.email ?? ""
        editPhone = user.phoneNumber ?? ""
        editGender = user.gender ?? ""
        editEthnicity = user.ethnicity ?? ""
        editInterests = user.fieldOfInterest ?? ""
        editHighSchool = user.highSchool ?? ""
        editNotes = relationship?.notes ?? ""
        
        isEditing = true
    }
    
    /// Save changes to contact profile
    private func saveChanges() {
        // Prepare update data
        var userData: [String: Any] = [:]
        
        userData["first_name"] = editFirstName
        userData["last_name"] = editLastName
        userData["job_title"] = editJobTitle
        userData["current_company"] = editCompany
        userData["university"] = editUniversity
        userData["uni_major"] = editUniMajor
        userData["location"] = editLocation
        userData["email"] = editEmail
        userData["phone_number"] = editPhone
        userData["gender"] = editGender
        userData["ethnicity"] = editEthnicity
        userData["field_of_interest"] = editInterests
        userData["high_school"] = editHighSchool
        
        // Store local reference to the relationship for use in closures
        let currentRelationship = relationship
        
        // Update the contact through coordinator
        coordinator.networkManager.updateUser(userId: user.id, userData: userData) { success in
            if success {
                // Fetch the updated user and update our @State variable
                self.coordinator.networkManager.fetchUser(withId: self.user.id) { result in
                    DispatchQueue.main.async {
                        if case .success(let updatedUser) = result {
                            // Overwrite the local @State user
                            self.user = updatedUser
                        }
                        
                        // Reset editing state
                        self.isEditing = false
                        
                        // Update the relationship with the new notes if we have a relationship
                        if let relationship = currentRelationship {
                            self.coordinator.networkManager.updateConnection(
                                contactId: self.user.id,
                                description: relationship.relationshipDescription,
                                notes: self.editNotes,
                                tags: relationship.tags
                            ) { success in
                                if success {
                                    // Refresh data after updating
                                    self.coordinator.networkManager.fetchConnections(forUserId: self.coordinator.networkManager.userId ?? 0)
                                    
                                    // Reload the specific relationship data
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        // Refresh the relationship in our local state
                                        self.relationship = self.coordinator.networkManager.connections.first { connection in
                                            return connection.id == self.user.id
                                        }
                                        
                                        // Force UI refresh
                                        self.refreshTrigger.toggle()
                                    }
                                }
                            }
                        } else {
                            // If no relationship to update, still force refresh the UI to show user data changes
                            self.refreshTrigger.toggle()
                        }
                    }
                }
            } else {
                // Reset editing state if the update failed
                self.isEditing = false
            }
        }
    }
    
    /// Cancel editing and reset fields
    private func cancelEditing() {
        isEditing = false
    }
    
    /// Delete the contact
    private func deleteContact() {
        coordinator.networkManager.deleteContact(contactId: user.id) { success in
            if success {
                // Navigate back
                coordinator.navigateBack()
            } else {
                // Handle error - could show an alert here
                print("Failed to delete contact")
            }
        }
    }
    
    // Color function to match NetworkView tag coloring
    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }
}