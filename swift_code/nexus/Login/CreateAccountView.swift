import SwiftUI

/// View for creating a new user account
struct CreateAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - State
    
    /// User's first name
    @State private var firstName = ""
    
    /// User's last name
    @State private var lastName = ""
    
    /// Desired username
    @State private var username = ""
    
    /// Password
    @State private var password = ""
    
    /// Confirm password
    @State private var confirmPassword = ""
    
    /// Whether username validation is in progress
    @State private var isCheckingUsername = false
    
    /// Whether the username is valid (not taken)
    @State private var isUsernameValid: Bool? = nil
    
    /// Whether to show password mismatch error
    @State private var showingPasswordMismatch = false
    
    /// Whether to show empty fields error
    @State private var showingEmptyFieldsError = false
    
    /// Error message to display
    @State private var errorMessage: String? = nil
    
    // MARK: - Computed Properties
    
    var isCreatingAccount: Bool {
        networkManager.isLoading
    }
    
    var canCreateAccount: Bool {
        !firstName.isEmpty && 
        !lastName.isEmpty && 
        !username.isEmpty && 
        !password.isEmpty && 
        password == confirmPassword && 
        (isUsernameValid == true)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    
                    TextField("Last Name", text: $lastName)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Account Information")) {
                    HStack {
                        TextField("Username", text: $username)
                            .font(.title3)
                            .padding(.vertical, 8)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: username) { _ in
                                // Reset availability when username changes
                                isUsernameValid = nil
                            }
                        
                        if !username.isEmpty {
                            Button(action: checkUsername) {
                                Text("Check")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                            .disabled(isCheckingUsername || username.isEmpty)
                        }
                    }
                    
                    if isCheckingUsername {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            Text("Checking username...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    } else if let isAvailable = isUsernameValid {
                        HStack {
                            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isAvailable ? .green : .red)
                            Text(isAvailable ? "Username is available" : "Username is already taken")
                                .font(.caption)
                                .foregroundColor(isAvailable ? .green : .red)
                        }
                    }
                    
                    SecureField("Password", text: $password)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .font(.title3)
                        .padding(.vertical, 8)
                        .textContentType(.oneTimeCode)
                        .autocapitalization(.none)
                        .onChange(of: confirmPassword) { _ in
                            showingPasswordMismatch = !confirmPassword.isEmpty && password != confirmPassword
                        }
                    
                    if showingPasswordMismatch {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: createAccount) {
                        if isCreatingAccount {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Creating Account...")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Text("Create Account")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(canCreateAccount ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!canCreateAccount || isCreatingAccount)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Methods
    
    /// Check if the username is available
    private func checkUsername() {
        guard !username.isEmpty else { return }
        
        isCheckingUsername = true
        isUsernameValid = nil
        
        networkManager.checkUsernameAvailability(username) { result in
            isCheckingUsername = false
            
            switch result {
            case .success(let isAvailable):
                isUsernameValid = isAvailable
            case .failure:
                // If check fails, assume it's not available to be safe
                isUsernameValid = false
                errorMessage = "Could not verify username. Please try again."
            }
        }
    }
    
    /// Create the account with the provided information
    private func createAccount() {
        // Validate inputs
        if firstName.isEmpty || lastName.isEmpty || username.isEmpty || password.isEmpty {
            showingEmptyFieldsError = true
            errorMessage = "Please fill in all fields"
            return
        }
        
        if password != confirmPassword {
            showingPasswordMismatch = true
            errorMessage = "Passwords do not match"
            return
        }
        
        if isUsernameValid != true {
            errorMessage = "Please check if your username is available"
            return
        }
        
        // Clear previous errors
        errorMessage = nil
        
        // Create user data dictionary for the people table - NOT including username field
        let userData: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "email": "",
            "phone_number": "",
            "gender": "",
            "ethnicity": "",
            "birthday": "",
            "location": "",
            "high_school": "",
            "university": "",
            "uni_major": "",
            "job_title": "",
            "current_company": "",
            "field_of_interest": "",
            "profile_image_url": "",
            "linkedin_url": "",
            "recent_tags": ""
        ]
        
        // Call network manager to create account with username as a separate parameter
        networkManager.createAccount(userData: userData, username: username, password: password) { result in
            switch result {
            case .success(let userId):
                print("Account created successfully with ID: \(userId)")
                
                // Automatically log in with the new credentials
                networkManager.login(username: username, password: password) { loginResult in
                    switch loginResult {
                    case .success:
                        // Dismiss this view and navigate to the main app
                        presentationMode.wrappedValue.dismiss()
                        // Coordinator will handle navigation to the main app
                        
                    case .failure(let error):
                        errorMessage = "Account created but login failed: \(error.localizedDescription)"
                    }
                }
                
            case .failure(let error):
                errorMessage = "Failed to create account: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CreateAccountView()
        .environmentObject(NetworkManager())
        .environmentObject(AppCoordinator())
} 