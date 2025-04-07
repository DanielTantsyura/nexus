import SwiftUI

/// The login view for the app
struct LoginView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - State
    
    /// The username entered by the user
    @State private var username: String = ""
    
    /// The password entered by the user
    @State private var password: String = ""
    
    /// Whether the login is currently in progress
    @State private var isLoggingIn = false
    
    /// Whether an error message should be shown
    @State private var showError = false
    
    /// The current error message to display
    @State private var errorMessage = "Invalid credentials. Please try again."
    
    /// Whether to show the create account view
    @State private var showingCreateAccount = false
    
    // MARK: - View
    
    var body: some View {
        VStack(spacing: 20) {
            // App logo
            Image("LogoWithText")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 220, height: 120)
                .padding(.bottom, 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Username")
                    .font(.title3)
                    .fontWeight(.medium)
                
                TextField("Enter your username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
                    .textContentType(.username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.vertical, 12)
                    .padding(.bottom, -15)
                    .disabled(isLoggingIn)
                
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.title3)
                    .fontWeight(.medium)
                
                SecureField("Enter your password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title2)
                    .textContentType(.password)
                    .padding(.vertical, 12)
                    .disabled(isLoggingIn)
            }
            
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 5)
            }
            
            // Container for buttons to ensure they have the same width
            VStack(spacing: 12) {
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
                
                Button(action: {
                    showingCreateAccount = true
                }) {
                    Text("Create Account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: 400)
        .padding(.top, 50)
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.networkManager)
        }
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
}

// MARK: - Previews

#Preview {
    LoginView()
        .environmentObject(AppCoordinator())
}
