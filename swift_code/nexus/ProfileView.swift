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
    
    /// Card displayed when profile is unavailable
    private var userProfileUnavailableCard: some View {
        SectionCard(title: "Profile") {
            VStack(spacing: 16) {
                Text("User profile not available")
                    .foregroundColor(.gray)
                    .padding()
                
                // Manual refresh button if retries have exceeded
                if retryAttempts >= 5 {
                    Button(action: {
                        retryAttempts = 0
                        loadUserData()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Profile")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Data Management
    
    /// Loads user data and sets up retry mechanism if needed
    private func loadUserData() {
        if coordinator.networkManager.userId != nil {
            coordinator.networkManager.fetchCurrentUser()
            
            // Set up a retry timer if currentUser is nil
            if coordinator.networkManager.currentUser == nil {
                setupRetryTimer()
            }
        }
    }
    
    /// Sets up a timer to retry loading user data
    private func setupRetryTimer() {
        // Invalidate existing timer if any
        invalidateRetryTimer()
        
        // Create a new timer that retries fetching user data
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if coordinator.networkManager.currentUser == nil && retryAttempts < 5 {
                retryAttempts += 1
                
                if coordinator.networkManager.userId != nil {
                    coordinator.networkManager.fetchCurrentUser()
                }
            } else {
                // Stop retrying after success or 5 attempts
                invalidateRetryTimer()
                retryAttempts = 0
            }
        }
    }
    
    /// Invalidates and clears the retry timer
    private func invalidateRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }
}

// MARK: - Previews

#Preview {
    ProfileView()
        .environmentObject(AppCoordinator())
} 