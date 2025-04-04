import SwiftUI

/// The login view for the app
struct LoginView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - State
    
    /// The username entered by the user
    @State private var username = ""
    
    /// The password entered by the user
    @State private var password = ""
    
    /// Whether the login is currently in progress
    @State private var isLoggingIn = false
    
    /// Whether an error message should be shown
    @State private var showError = false
    
    /// The current error message to display
    @State private var errorMessage = "Invalid credentials. Please try again."
    
    // MARK: - View
    
    var body: some View {
        VStack(spacing: 20) {
            // App logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.headline)
                
                TextField("Enter your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.bottom, 10)
                    .disabled(isLoggingIn)
                
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.headline)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.password)
                    .disabled(isLoggingIn)
            }
            
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 5)
            }
            
            Button(action: loginAction) {
                Group {
                    if isLoggingIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(username.isEmpty || password.isEmpty || isLoggingIn)
            .padding(.top, 20)
            
            Button("Create Account") {
                showCreateAccount()
            }
            .foregroundColor(.blue)
            .padding(.top, 5)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .padding(.top, 50)
    }
    
    // MARK: - Actions
    
    /// Attempt to log in with the provided credentials
    private func loginAction() {
        isLoggingIn = true
        showError = false
        
        coordinator.networkManager.login(username: username, password: password) { result in
            isLoggingIn = false
            
            switch result {
            case .success:
                // Login successful, coordinator will handle navigation
                break
            case .failure(let error):
                // Show error message
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    /// Navigate to the create account screen
    private func showCreateAccount() {
        // Implementation for navigating to account creation
    }
    
}

// MARK: - Previews

#Preview {
    LoginView()
        .environmentObject(AppCoordinator())
} 