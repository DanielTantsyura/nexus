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
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // App logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 60)
                    .padding(.bottom, 10)
                
                // Current user profile section
                currentUserSection
                
                // Settings section with logout
                settingsSection
                
                Spacer(minLength: 50)
            }
            .padding()
        }
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