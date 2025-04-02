import SwiftUI

/// Main profile dashboard view displaying user profile and navigation options
struct ProfileView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// Controls visibility of the logout confirmation dialog
    @State private var showLogoutConfirmation = false
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App header
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                )
                .padding(.bottom, 10)
                
                // Title
                Text("Your Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Current user profile section
                currentUserSection
                
                // Settings section with logout
                settingsSection
                
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
            
            // Auto-retry loading profile if it's missing
            coordinator.autoRetryLoading(
                check: { self.coordinator.networkManager.currentUser != nil },
                action: { self.coordinator.networkManager.fetchCurrentUser() }
            )
        }
        .onChange(of: coordinator.activeScreen) { oldValue, newValue in
            if newValue == .profile {
                print("ProfileView: Active screen changed to profile")
                // Only force refresh when returning to profile screen if data is missing
                if coordinator.networkManager.currentUser == nil {
                    print("ProfileView: User data missing, refreshing")
                    loadUserData()
                    
                    // Force UI update by creating a dummy change to trigger refresh
                    // But only if data is still missing after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if self.coordinator.networkManager.currentUser == nil {
                            print("ProfileView: Still no data after screen change, forcing UI update")
                            coordinator.objectWillChange.send()
                        }
                    }
                } else {
                    print("ProfileView: User data already loaded, no refresh needed")
                }
            }
        }
        .onChange(of: coordinator.networkManager.currentUser) { oldValue, newValue in
            if newValue != nil && oldValue == nil {
                print("ProfileView: Current user changed from nil to loaded, forcing UI refresh")
                // Only trigger UI refresh when user data goes from nil to non-nil
                coordinator.objectWillChange.send()
            }
        }
    }
    
    // MARK: - UI Components
    
    /// Settings section with logout option
    private var settingsSection: some View {
        SectionCard(title: "Settings") {
            Button(action: {
                showLogoutConfirmation = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.red)
                        .cornerRadius(10)
                    
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
    
    /// Logout confirmation alert
    private var logoutAlert: Alert {
        Alert(
            title: Text("Logout"),
            message: Text("Are you sure you want to logout?"),
            primaryButton: .destructive(Text("Logout")) {
                print("User confirmed logout")
                coordinator.logout()
                
                // Force UI update after logout
                DispatchQueue.main.async {
                    // Ensure we navigate to login screen
                    coordinator.activeScreen = .login
                }
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
                
                // Contact Information
                contactInformationSection(user: user)
                
                Divider()
                
                // Education & Skills
                educationAndSkillsSection(user: user)
                
                // Edit profile button
                Button(action: {
                    coordinator.showEditProfile()
                }) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Profile")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
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
                Text(user.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let jobTitle = user.jobTitle {
                    Text(jobTitle)
                        .font(.headline)
                        .foregroundColor(.blue)
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
    
    /// Contact information section
    private func contactInformationSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information")
                .font(.headline)
                .padding(.bottom, 4)
            
            if let email = user.email {
                InfoRow(icon: "envelope.fill", title: "Email", value: email)
            }
            
            if let phone = user.phoneNumber {
                InfoRow(icon: "phone.fill", title: "Phone", value: phone)
            }
            
            if let location = user.location {
                InfoRow(icon: "location.fill", title: "Location", value: location)
            }
        }
    }
    
    /// Education and skills section
    private func educationAndSkillsSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Education & Skills")
                .font(.headline)
                .padding(.bottom, 4)
            
            if let university = user.university {
                InfoRow(icon: "building.columns.fill", title: "University", value: university)
            }
            
            if let major = user.uniMajor {
                InfoRow(icon: "book.fill", title: "Major", value: major)
            }
            
            if let interests = user.fieldOfInterest {
                InfoRow(icon: "star.fill", title: "Interests", value: interests)
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