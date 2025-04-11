import SwiftUI
import Combine

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
    
    /// State to track if user just created a new account and needs to complete profile
    @State private var isNewAccount = false
    
    /// Toggle to force UI refresh
    @State private var refreshTrigger = false
    
    /// Cancellable store for the refresh signal subscription
    @State private var refreshCancellable: AnyCancellable?
    
    /// Cancellable store for the refresh signal subscription
    @State private var cancellables = Set<AnyCancellable>()
    
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
    @State private var editCompany = ""
    @State private var editLinkedinUrl = ""
    @State private var editBirthday = ""
    
    @State private var showingImageUrlSheet = false
    @State private var imageUrlInput = ""
    
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
                            .font(.system(size: 24))
                            .frame(height: 50)
                    }
                }
                .padding(.bottom, 5)
                
                // Current user profile section
                currentUserSection
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .id("profile-view-\(refreshTrigger)") // Force entire view to refresh when data changes
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .alert(isPresented: $showLogoutConfirmation) {
            logoutAlert
        }
        .sheet(isPresented: $showingImageUrlSheet) {
            // Sheet for editing profile image URL
            NavigationView {
                Form {
                    Section(header: Text("Profile Image URL")) {
                        TextField("Paste image URL here", text: $imageUrlInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !imageUrlInput.isEmpty, let url = URL(string: imageUrlInput) {
                            VStack {
                                Text("Preview:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView()
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    case .failure:
                                        Text("Failed to load image")
                                            .foregroundColor(.red)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                    
                    Section {
                        Button("Clear Image URL") {
                            imageUrlInput = ""
                        }
                        .foregroundColor(.red)
                    }
                }
                .navigationTitle("Edit Profile Image")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingImageUrlSheet = false
                        }
                    }
                }
            }
        }
        .onAppear {
            coordinator.activeScreen = .profile

            // 1) If new account creation was flagged, capture it immediately
            if coordinator.isNewAccountCreation {
                isNewAccount = true
                coordinator.isNewAccountCreation = false
            }

            // 2) Now see if currentUser is already loaded
            if let currentUser = coordinator.networkManager.currentUser {
                // Force UI refresh
                refreshTrigger.toggle()
                
                // If we know it's a brand-new account, start editing right away
                if isNewAccount {
                    startEditing(currentUser)
                }
            } 
            // 3) If still nil, attempt loading, but isNewAccount remains true
            else if !coordinator.networkManager.isLoading {
                loadUserData()
            }

            // 4) Listen for refresh signals
            refreshCancellable = coordinator.networkManager.$refreshSignal
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    let refreshType = coordinator.networkManager.lastRefreshType
                    
                    if refreshType == .profile || refreshType == .currentUser {
                        refreshTrigger.toggle()
                        invalidateRetryTimer()
                        
                        // If new account & user has since loaded, start editing
                        if isNewAccount, let user = coordinator.networkManager.currentUser {
                            startEditing(user)
                            isNewAccount = false
                        }
                    }
                }

            // Also watch currentUser directly, etc.
            coordinator.networkManager.$currentUser
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    refreshTrigger.toggle()
                }
                .store(in: &cancellables)
        }
        .onDisappear {
            // Invalidate timer when view disappears
            invalidateRetryTimer()
            refreshCancellable?.cancel()
            cancellables.forEach { $0.cancel() }
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
            // Prioritize showing the profile if it's available
            if let currentUser = coordinator.networkManager.currentUser {
                userProfileCard(user: currentUser)
                    .id(refreshTrigger) // Force rebuild when refresh happens
            } else if coordinator.networkManager.isLoading {
                LoadingView(message: "Loading profile...")
            } else {
                userProfileUnavailableCard
            }
        }
        .id("profile-section-\(refreshTrigger)") // Ensure section refreshes when data changes
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
                HStack(spacing: 12) {
                    if isEditing {
                        Button(action: {
                            saveChanges(user)
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                    .imageScale(.small)
                                Text("Save")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
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
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            startEditing(user)
                        }) {
                            HStack {
                                Image(systemName: "square.and.pencil")
                                    .imageScale(.small)
                                Text("Edit Profile")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    /// Profile header with avatar and basic info
    private func profileHeader(user: User) -> some View {
        HStack {
            // Avatar with edit capability
            ZStack {
                UserAvatar(user: user, size: 80)
                if isEditing {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showImageUrlDialog()
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                                    .background(Color.white.clipShape(Circle()))
                            }
                            .offset(x: 5, y: 5)
                        }
                    }
                    .frame(width: 80, height: 80)
                }
            }
            
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
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Job title and company on second line
                    HStack(spacing: 8) {
                        if let jobTitle = user.jobTitle {
                            Text(jobTitle)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                        
                        // Company with icon if available
                        if let company = user.currentCompany, !company.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "building.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.6))
                                Text(company)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
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
                // Birthday field - placed at the top
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Birthday")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("MM/DD/YYYY", text: $editBirthday)
                    }
                }
                
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
                
                // LinkedIn field - placed under phone
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LinkedIn")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("LinkedIn URL", text: $editLinkedinUrl)
                    }
                }
            } else {
                // Birthday field - placed at the top
                if let birthday = user.birthday {
                    InfoRow(icon: "calendar", title: "Birthday", value: birthday)
                }
                
                if let email = user.email {
                    InfoRow(icon: "envelope.fill", title: "Email", value: email)
                }
                
                if let phone = user.phoneNumber {
                    InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                }
                
                // LinkedIn field - placed under phone
                if let linkedin = user.linkedinUrl, !linkedin.isEmpty {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("LinkedIn")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let url = URL(string: linkedin), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            print("Invalid LinkedIn URL: \(linkedin)")
                        }
                    }
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
        editCompany = user.currentCompany ?? ""
        editLinkedinUrl = user.linkedinUrl ?? ""
        editBirthday = user.birthday ?? ""
        imageUrlInput = user.profileImageUrl ?? ""
        
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
        userData["current_company"] = editCompany
        userData["linkedin_url"] = editLinkedinUrl
        userData["birthday"] = editBirthday
        userData["profile_image_url"] = imageUrlInput
        
        // Update the user through coordinator
        coordinator.networkManager.updateUser(userId: user.id, userData: userData) { result in
            switch result {
            case .success:
                // Refresh user data once only
                self.coordinator.networkManager.fetchCurrentUser()
                
                // Reset editing state
                self.isEditing = false
                
                // Force a single UI refresh after saving
                self.refreshTrigger.toggle()
            case .failure:
                self.isEditing = false
            }
        }
    }
    
    /// Cancel editing and reset fields
    private func cancelEditing() {
        isEditing = false
    }
    
    // MARK: - Helper Methods
    
    /// Loads the current user's data
    private func loadUserData() {
        // Only fetch if we don't have data and are not already loading
        if coordinator.networkManager.currentUser == nil && !coordinator.networkManager.isLoading {
            coordinator.networkManager.fetchCurrentUser()
            
            // Set up a task to retry once if needed after a delay
            Task {
                // Wait a moment to see if the data loads
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                // If still no data, try once more - no cascade of refreshes
                if coordinator.networkManager.currentUser == nil && !coordinator.networkManager.isLoading {
                    coordinator.networkManager.fetchCurrentUser()
                }
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

    private func showImageUrlDialog() {
        if let user = coordinator.networkManager.currentUser {
            // Initialize with current image URL if available
            imageUrlInput = user.profileImageUrl ?? ""
            showingImageUrlSheet = true
        }
    }
}
