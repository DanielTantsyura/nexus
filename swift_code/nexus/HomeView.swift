import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var showLogoutConfirmation = false
    @State private var retryAttempts = 0
    @State private var retryTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current user profile section
                currentUserSection
                
                // Navigation options
                navigationSection
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showLogoutConfirmation = true
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                }
            }
        }
        .alert(isPresented: $showLogoutConfirmation) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to logout?"),
                primaryButton: .destructive(Text("Logout")) {
                    coordinator.logout()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            // Refresh current user data when view appears
            coordinator.activeScreen = .home
            loadUserData()
        }
        .onDisappear {
            // Invalidate timer when view disappears
            retryTimer?.invalidate()
            retryTimer = nil
        }
    }
    
    private func loadUserData() {
        if coordinator.networkManager.userId != nil {
            coordinator.networkManager.fetchCurrentUser()
            
            // Set up a retry timer if currentUser is nil
            if coordinator.networkManager.currentUser == nil {
                setupRetryTimer()
            }
        }
    }
    
    private func setupRetryTimer() {
        // Invalidate existing timer if any
        retryTimer?.invalidate()
        
        // Create a new timer that retries fetching user data
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if coordinator.networkManager.currentUser == nil && retryAttempts < 5 {
                print("Retrying profile data fetch, attempt \(retryAttempts + 1)")
                retryAttempts += 1
                
                if coordinator.networkManager.userId != nil {
                    coordinator.networkManager.fetchCurrentUser()
                }
            } else {
                // Stop retrying after success or 5 attempts
                retryTimer?.invalidate()
                retryTimer = nil
                retryAttempts = 0
            }
        }
    }
    
    private var currentUserSection: some View {
        Group {
            if coordinator.networkManager.isLoading && coordinator.networkManager.currentUser == nil {
                LoadingView(message: "Loading profile...")
            } else if let currentUser = coordinator.networkManager.currentUser {
                SectionCard(title: "My Profile") {
                    VStack(spacing: 15) {
                        // Profile header
                        HStack {
                            // Avatar
                            UserAvatar(user: currentUser, size: 80)
                            
                            // User info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.fullName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                if let jobTitle = currentUser.jobTitle {
                                    Text(jobTitle)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                
                                if let company = currentUser.currentCompany {
                                    Text(company)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.leading, 10)
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contact Information")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            if let email = currentUser.email {
                                InfoRow(icon: "envelope.fill", title: "Email", value: email)
                            }
                            
                            if let phone = currentUser.phoneNumber {
                                InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                            }
                            
                            if let location = currentUser.location {
                                InfoRow(icon: "location.fill", title: "Location", value: location)
                            }
                        }
                        
                        Divider()
                        
                        // Education & Skills
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Education & Skills")
                                .font(.headline)
                                .padding(.bottom, 4)
                            
                            if let university = currentUser.university {
                                InfoRow(icon: "building.columns.fill", title: "University", value: university)
                            }
                            
                            if let major = currentUser.uniMajor {
                                InfoRow(icon: "book.fill", title: "Major", value: major)
                            }
                            
                            if let interests = currentUser.fieldOfInterest {
                                InfoRow(icon: "star.fill", title: "Interests", value: interests)
                            }
                        }
                        
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
            } else {
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
        }
    }
    
    private var navigationSection: some View {
        SectionCard(title: "Connect with the Network") {
            // Use direct navigation
            NavigationLink(value: ActiveScreen.userList) {
                navigationButton(
                    title: "Browse All Users",
                    icon: "person.3.fill",
                    color: .green
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func navigationButton(title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(color)
                .cornerRadius(10)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppCoordinator())
} 