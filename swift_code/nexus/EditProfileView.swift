import SwiftUI

/// View for editing user profile information
struct EditProfileView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    /// Optional user to edit. If nil, edit current user profile
    var user: User?
    
    /// Whether the view is in a sheet or in the navigation stack
    private var isInSheet: Bool {
        return user != nil
    }
    
    /// Alert control properties
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var saveSuccess = false
    
    // MARK: - User Field States
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var location: String = ""
    @State private var university: String = ""
    @State private var uniMajor: String = ""
    @State private var highSchool: String = ""
    @State private var jobTitle: String = ""
    @State private var company: String = ""
    @State private var interests: String = ""
    @State private var gender: String = ""
    @State private var ethnicity: String = ""
    
    // MARK: - View Body
    
    var body: some View {
        Group {
            if isInSheet {
                // For contacts, show in a NavigationView
                NavigationView {
                    profileEditContent
                        .navigationTitle("Edit Contact")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cancel") {
                                    dismiss()
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Save") {
                                    saveProfile()
                                }
                                .disabled(coordinator.networkManager.isLoading)
                            }
                        }
                }
            } else {
                // For current user, use existing navigation stack
                profileEditContent
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            if !isInSheet {
                coordinator.activeScreen = .editProfile
            }
            loadUserData()
        }
        .alert(isPresented: $showingSaveAlert) {
            Alert(
                title: Text(saveSuccess ? "Success" : "Error"),
                message: Text(saveAlertMessage),
                dismissButton: .default(Text("OK")) {
                    if saveSuccess {
                        if isInSheet {
                            dismiss()
                        } else {
                            // Navigate back
                            coordinator.navigationPath.removeLast()
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - UI Components
    
    /// Content view for profile editing
    private var profileEditContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar display
                avatarSection
                
                // Form fields
                formFieldsSection
            }
            .padding(.vertical)
        }
    }
    
    /// Avatar display section
    private var avatarSection: some View {
        Group {
            if let userToEdit = user {
                UserAvatar(user: userToEdit, size: 100)
            } else if let currentUser = coordinator.networkManager.currentUser {
                UserAvatar(user: currentUser, size: 100)
            }
        }
    }
    
    /// Form fields for editing user information
    private var formFieldsSection: some View {
        VStack(spacing: 16) {
            // Personal Information
            SectionCard(title: "Personal Information") {
                VStack(spacing: 12) {
                    formTextField(title: "First Name", text: $firstName)
                    formTextField(title: "Last Name", text: $lastName)
                    formTextField(title: "Email", text: $email, keyboardType: .emailAddress)
                    formTextField(title: "Phone Number", text: $phoneNumber, keyboardType: .phonePad)
                    formTextField(title: "Gender", text: $gender)
                    formTextField(title: "Ethnicity", text: $ethnicity)
                    formTextField(title: "Location", text: $location)
                }
            }
            
            // Professional Information
            SectionCard(title: "Professional Information") {
                VStack(spacing: 12) {
                    formTextField(title: "Job Title", text: $jobTitle)
                    formTextField(title: "Company", text: $company)
                    formMultilineField(title: "Professional Interests", text: $interests)
                }
            }
            
            // Education
            SectionCard(title: "Education") {
                VStack(spacing: 12) {
                    formTextField(title: "University", text: $university)
                    formTextField(title: "Major", text: $uniMajor)
                    formTextField(title: "High School", text: $highSchool)
                }
            }
            
            // Save button (only show for current user profile)
            if !isInSheet {
                Button(action: saveProfile) {
                    if coordinator.networkManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Save Changes")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(coordinator.networkManager.isLoading)
                .padding(.top, 10)
            }
        }
        .padding()
    }
    
    // MARK: - Form Components
    
    /// Creates a text input field with a title
    /// - Parameters:
    ///   - title: Label for the field
    ///   - text: Binding for the field value
    ///   - keyboardType: Type of keyboard to display
    private func formTextField(title: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField(title, text: text)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .keyboardType(keyboardType)
        }
    }
    
    /// Creates a multiline text input field with a title
    /// - Parameters:
    ///   - title: Label for the field
    ///   - text: Binding for the field value
    private func formMultilineField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextEditor(text: text)
                .frame(minHeight: 100)
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Data Methods
    
    /// Loads user data into form fields
    private func loadUserData() {
        // Determine which user to load data from
        let userToLoad: User?
        if let user = user {
            // Load contact data
            userToLoad = user
        } else {
            // Load current user data
            userToLoad = coordinator.networkManager.currentUser
        }
        
        guard let userData = userToLoad else { return }
        
        firstName = userData.firstName ?? ""
        lastName = userData.lastName ?? ""
        email = userData.email ?? ""
        phoneNumber = userData.phoneNumber ?? ""
        location = userData.location ?? ""
        university = userData.university ?? ""
        uniMajor = userData.uniMajor ?? ""
        highSchool = userData.highSchool ?? ""
        jobTitle = userData.jobTitle ?? ""
        company = userData.currentCompany ?? ""
        interests = userData.fieldOfInterest ?? ""
        gender = userData.gender ?? ""
        ethnicity = userData.ethnicity ?? ""
    }
    
    /// Saves the current profile or contact information
    private func saveProfile() {
        // Create updated user object from form data
        let updatedUser = User(
            id: user?.id ?? (coordinator.networkManager.userId ?? 0),
            username: user?.username,
            firstName: firstName,
            lastName: lastName,
            email: email,
            phoneNumber: phoneNumber,
            location: location,
            university: university,
            fieldOfInterest: interests,
            highSchool: highSchool,
            birthday: user?.birthday,
            createdAt: user?.createdAt,
            currentCompany: company,
            gender: gender,
            ethnicity: ethnicity,
            uniMajor: uniMajor,
            jobTitle: jobTitle
        )
        
        coordinator.networkManager.updateUser(updatedUser) { success in
            saveSuccess = success
            saveAlertMessage = success 
                ? isInSheet ? "Contact information has been updated successfully." : "Your profile has been updated successfully."
                : coordinator.networkManager.errorMessage ?? (isInSheet ? "Failed to update contact." : "Failed to update profile.")
            showingSaveAlert = true
        }
    }
}

// MARK: - Previews

#Preview("Edit Profile") {
    NavigationView {
        EditProfileView()
            .environmentObject(AppCoordinator())
    }
}

#Preview("Edit Contact") {
    EditProfileView(user: User(
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
        currentCompany: "Tech Corp",
        gender: nil,
        ethnicity: nil,
        uniMajor: "Computer Science",
        jobTitle: "Software Engineer"
    ))
    .environmentObject(AppCoordinator())
} 
