import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo and header
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
            
            // Login form
            VStack(spacing: 16) {
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
                
                if coordinator.networkManager.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    Button(action: {
                        loginUser()
                    }) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                    .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1)
                }
            }
            .padding(.horizontal, 40)
            
            // Error message
            if let errorMessage = coordinator.networkManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Help text
            VStack(spacing: 8) {
                Text("Forgot your password?")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {
                    showingAlert = true
                    alertMessage = "All accounts have password: 'password'"
                }) {
                    Text("Need help signing in?")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding(.vertical, 50)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Help"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loginUser() {
        coordinator.login(username: username, password: password) { success in
            if !success {
                showingAlert = true
                alertMessage = coordinator.networkManager.errorMessage ?? "Failed to login"
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AppCoordinator())
} 