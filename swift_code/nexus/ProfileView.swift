import SwiftUI

/// Main profile dashboard view displaying user profile and navigation options
struct ProfileView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// Controls visibility of the logout confirmation dialog
    @State private var showLogoutConfirmation = false
    
    /// Tracks the number of data loading retry attempts
    @State private var retryAttempts = 0
    
    /// Timer for automatic retry of loading user data
    @State private var retryTimer: Timer?
    
    /// State to track whether the view is in edit mode
    @State private var isEditing = false
    
    // Editing state variables
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var editJobTitle = ""
    @State private var editUniversity = ""
    @State private var editLocation = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editMajor = ""
    @State private var editInterests = ""
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // App header with integrated logout button
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                ) {
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
                    }
                }
                .padding(.bottom, 5)
                
                // Current user profile section
                currentUserSection
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showLogoutConfirmation) {
            logoutAlert
        }
        .onAppear {
            // Refresh current user data when view appears
            coordinator.activeScreen = .profile
            loadUserData()
        }
        .onDisappear {
            // Invalidate timer when view disappears
            invalidateRetryTimer()
        }
    }
    
    // MARK: - UI Components
    
    /// Logout confirmation alert
    private var logoutAlert: Alert {
        Alert(
            title: Text("Logout"),
            message: Text("Are you sure you want to logout?"),
            primaryButton: .destructive(Text("Logout")) {
                coordinator.logout()
            },
            secondaryButton: .cancel()
        )
    }
    
    /// Section displaying current user profile information
    private var currentUserSection: some View {
        Group {
            if coordinator.networkManager.isLoading && coordinator.networkManager.currentUser == nil {
                LoadingView(message: "Loading profile...")
            } else if let currentUser = coordinator.networkManager.currentUser {
                userProfileCard(user: currentUser)
            } else {
                userProfileUnavailableCard
            }
        }
    }
    
    /// Card displaying detailed user profile information
    private func userProfileCard(user: User) -> some View {
        SectionCard(title: "My Profile") {
            VStack(spacing: 15) {
                // Profile header with avatar and basic info
                profileHeader(user: user)
                
                Divider()
                
                // Things I care about section - with major and interests
                thingsICareAboutSection(user: user)
                
                Divider()
                
                // Contact Information
                contactInformationSection(user: user)
                
                // Edit/Save/Cancel buttons
                HStack {
                    if isEditing {
                        Button(action: {
                            saveChanges(user)
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Save")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        
                        Button(action: {
                            cancelEditing()
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Cancel")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    } else {
                        Button(action: {
                            startEditing(user)
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("Edit Profile")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    /// Profile header with avatar and basic info
    private func profileHeader(user: User) -> some View {
        HStack {
            // Avatar
            UserAvatar(user: user, size: 80)
            
            // User info
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
                    
                    // Job title field
                    TextField("Job Title", text: $editJobTitle)
                        .font(.subheadline)
                    
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
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Job title on second line
                    if let jobTitle = user.jobTitle {
                        Text(jobTitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // University and location on third line
                    HStack(spacing: 8) {
                        if let university = user.university, !university.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "building.columns.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.7))
                                Text(university)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let location = user.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let company = user.currentCompany {
                    Text(company)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading, 10)
            
            Spacer()
        }
    }
    
    /// Things I care about section with major and interests
    private func thingsICareAboutSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Things I care about")
                .font(.headline)
                .padding(.bottom, 4)
            
            if isEditing {
                HStack {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Major")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("Major", text: $editMajor)
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
                if let major = user.uniMajor {
                    InfoRow(icon: "book.fill", title: "Major", value: major)
                }
                
                if let interests = user.fieldOfInterest {
                    InfoRow(icon: "star.fill", title: "Interests", value: interests)
                }
            }
        }
    }
    
    /// Contact information section
    private func contactInformationSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)
                .padding(.bottom, 4)
            
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
            } else {
                if let email = user.email {
                    InfoRow(icon: "envelope.fill", title: "Email", value: email)
                }
                
                if let phone = user.phoneNumber {
                    InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                }
            }
        }
    }
    
    /// Card to display when user profile is unavailable
    private var userProfileUnavailableCard: some View {
        SectionCard(title: "My Profile") {
            VStack(spacing: 16) {
                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                    .padding()
                
                Text("Profile unavailable")
                    .font(.headline)
                
                Text("We couldn't load your profile information. Please try again.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    loadUserData()
                }) {
                    Text("Retry")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
        }
    }
    
    // MARK: - Edit Mode Methods
    
    /// Initialize edit mode with current user data
    private func startEditing(_ user: User) {
        editFirstName = user.firstName ?? ""
        editLastName = user.lastName ?? ""
        editJobTitle = user.jobTitle ?? ""
        editUniversity = user.university ?? ""
        editLocation = user.location ?? ""
        editEmail = user.email ?? ""
        editPhone = user.phoneNumber ?? ""
        editMajor = user.uniMajor ?? ""
        editInterests = user.fieldOfInterest ?? ""
        
        isEditing = true
    }
    
    /// Save changes to user profile
    private func saveChanges(_ user: User) {
        // Prepare update data
        var userData: [String: Any] = [:]
        
        userData["first_name"] = editFirstName
        userData["last_name"] = editLastName
        userData["job_title"] = editJobTitle
        userData["university"] = editUniversity
        userData["location"] = editLocation
        userData["email"] = editEmail
        userData["phone_number"] = editPhone
        userData["uni_major"] = editMajor
        userData["field_of_interest"] = editInterests
        
        // Update the user through coordinator
        coordinator.networkManager.updateUser(userId: user.id, userData: userData) { success in
            if success {
                // Refresh user data
                self.coordinator.networkManager.fetchCurrentUser()
            }
            self.isEditing = false
        }
    }
    
    /// Cancel editing and reset fields
    private func cancelEditing() {
        isEditing = false
    }
    
    // MARK: - Helper Methods
    
    /// Loads the current user's data
    private func loadUserData() {
        coordinator.networkManager.fetchCurrentUser()
        
        // Set up a timer to retry if needed
        setupRetryTimer()
    }
    
    /// Sets up a timer to retry loading user data if initial attempt fails
    private func setupRetryTimer() {
        retryTimer?.invalidate()
        retryAttempts = 0
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if self.coordinator.networkManager.currentUser == nil && !self.coordinator.networkManager.isLoading {
                if self.retryAttempts < 2 {
                    self.retryAttempts += 1
                    self.coordinator.networkManager.fetchCurrentUser()
                } else {
                    self.invalidateRetryTimer()
                }
            } else {
                self.invalidateRetryTimer()
            }
        }
    }
    
    /// Invalidates and clears the retry timer
    private func invalidateRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(AppCoordinator())
    }
}