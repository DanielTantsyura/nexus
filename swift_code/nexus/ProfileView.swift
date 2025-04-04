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
    
    /// Toggle to force UI refresh
    @State private var refreshTrigger = false
    
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
            Task {
                loadUserData()
                // Add a small delay and trigger a refresh to ensure UI updates
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                refreshTrigger.toggle() // Force UI update
            }
        }
        .onDisappear {
            // Invalidate timer when view disappears
            invalidateRetryTimer()
        }
        .id(refreshTrigger) // Force view to refresh when trigger changes
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
        
        // Set up a task to retry if needed after a delay
        Task {
            // Wait a moment to see if the data loads
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // If still no data, try once more and trigger refresh
            if coordinator.networkManager.currentUser == nil && !coordinator.networkManager.isLoading {
                coordinator.networkManager.fetchCurrentUser()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                refreshTrigger.toggle() // Force UI update
            }
        }
    }
    
    /// Sets up a timer to retry loading user data if initial attempt fails
    private func setupRetryTimer() {
        // This method is kept for backward compatibility but we use Task-based approach now
        retryTimer?.invalidate()
        retryAttempts = 0
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