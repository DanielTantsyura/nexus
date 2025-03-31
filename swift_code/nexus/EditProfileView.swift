import SwiftUI

/// View for editing user profile information
struct EditProfileView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
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
        ScrollView {
            VStack(spacing: 20) {
                // Avatar display
                avatarSection
                
                // Form fields
                formFieldsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            coordinator.activeScreen = .editProfile
            loadUserData()
        }
        .alert(isPresented: $showingSaveAlert) {
            Alert(
                title: Text(saveSuccess ? "Success" : "Error"),
                message: Text(saveAlertMessage),
                dismissButton: .default(Text("OK")) {
                    if saveSuccess {
                        // Navigate back
                        coordinator.navigationPath.removeLast()
                    }
                }
            )
        }
    }
    
    // MARK: - UI Components
    
    /// Avatar display section
    private var avatarSection: some View {
        Group {
            if let currentUser = coordinator.networkManager.currentUser {
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
            
            // Save button
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
        guard let currentUser = coordinator.networkManager.currentUser else { return }
        
        firstName = currentUser.firstName ?? ""
        lastName = currentUser.lastName ?? ""
        email = currentUser.email ?? ""
        phoneNumber = currentUser.phoneNumber ?? ""
        location = currentUser.location ?? ""
        university = currentUser.university ?? ""
        uniMajor = currentUser.uniMajor ?? ""
        highSchool = currentUser.highSchool ?? ""
        jobTitle = currentUser.jobTitle ?? ""
        company = currentUser.currentCompany ?? ""
        interests = currentUser.fieldOfInterest ?? ""
        gender = currentUser.gender ?? ""
        ethnicity = currentUser.ethnicity ?? ""
    }
    
    /// Saves updated profile information to the API
    private func saveProfile() {
        guard let userId = coordinator.networkManager.userId else { return }
        
        let userData: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": email,
            "phone_number": phoneNumber,
            "location": location,
            "university": university,
            "uni_major": uniMajor,
            "high_school": highSchool,
            "job_title": jobTitle,
            "current_company": company,
            "field_of_interest": interests,
            "gender": gender,
            "ethnicity": ethnicity
        ]
        
        coordinator.networkManager.updateUserProfile(userId: userId, userData: userData) { success in
            saveSuccess = success
            saveAlertMessage = success 
                ? "Your profile has been updated successfully."
                : coordinator.networkManager.errorMessage ?? "Failed to update profile."
            showingSaveAlert = true
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        EditProfileView()
            .environmentObject(AppCoordinator())
    }
} 