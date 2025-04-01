import SwiftUI

/// View that handles user authentication
struct LoginView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// Username input field value
    @State private var username: String = ""
    
    /// Password input field value
    @State private var password: String = ""
    
    /// Controls visibility of alert messages
    @State private var showingAlert = false
    
    /// Content of the alert message
    @State private var alertMessage = ""
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 30) {
            logoSection
            loginFormSection
            errorMessageView
            helpSection
            Spacer()
        }
        .padding(.vertical, 50)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Information"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - UI Components
    
    /// Logo and app header section
    private var logoSection: some View {
        VStack(spacing: 20) {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                )
            
            Text("Nexus Network")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Connect with your professional network")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    /// Login form with username, password inputs and sign in button
    private var loginFormSection: some View {
        VStack(spacing: 16) {
            credentialFields
            loginButton
        }
        .padding(.horizontal, 40)
    }
    
    /// Username and password input fields
    private var credentialFields: some View {
        Group {
            TextField("Username", text: $username)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
        }
    }
    
    /// Login button or progress indicator
    private var loginButton: some View {
        Group {
            if coordinator.networkManager.isLoading {
                ProgressView()
                    .padding()
            } else {
                Button(action: loginUser) {
                    Text("Sign In")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isLoginDisabled)
                .opacity(isLoginDisabled ? 0.6 : 1)
            }
        }
    }
    
    /// Whether the login button should be disabled
    private var isLoginDisabled: Bool {
        username.isEmpty || password.isEmpty
    }
    
    /// Displays error messages from the network manager
    private var errorMessageView: some View {
        Group {
            if let errorMessage = coordinator.networkManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    /// Help text and password hint section
    private var helpSection: some View {
        VStack(spacing: 8) {
            Text("Forgot your password?")
                .font(.caption)
                .foregroundColor(.gray)
            
            Button(action: showPasswordHint) {
                Text("Need help signing in?")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Actions
    
    /// Shows password hint in an alert
    private func showPasswordHint() {
        showingAlert = true
        alertMessage = "All accounts have password: 'password'"
    }
    
    /// Attempts to log in the user with provided credentials
    private func loginUser() {
        coordinator.login(username: username, password: password) { success in
            if !success {
                showingAlert = true
                alertMessage = coordinator.networkManager.errorMessage ?? "Failed to login"
            }
        }
    }
}

// MARK: - Previews

#Preview {
    LoginView()
        .environmentObject(AppCoordinator())
} 