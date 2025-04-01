import SwiftUI

/// Displays detailed information about a user including their profile and connections
struct UserDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let user: User
    @State private var showingAddConnectionSheet = false
    @State private var connectionLoadAttempts = 0
    @State private var localConnections: [Connection] = []
    @State private var retryTimer: Timer?
    @State private var forceShowEmptyState = false
    @State private var showingEditContactSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section
                userInfoSection
                
                // Connections section
                connectionsSection
            }
            .padding()
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditContactSheet = true
                }) {
                    Image(systemName: "pencil")
                }
            }
        }
        .onAppear {
            coordinator.activeScreen = .userDetail
            loadConnections(forceReload: true)
            setupConnectionLoadTimers()
        }
        .onDisappear {
            retryTimer?.invalidate()
            retryTimer = nil
        }
        .onChange(of: user.id) { _, _ in
            loadConnections(forceReload: true)
        }
        .onChange(of: coordinator.networkManager.connections) { _, _ in
            updateLocalConnections()
        }
        .sheet(isPresented: $showingAddConnectionSheet, onDismiss: {
            loadConnections(forceReload: true)
        }) {
            AddConnectionView(userId: user.id)
        }
    }
    
    // MARK: - Subviews
    
    /// Displays user profile information including personal details and education/work history
    private var userInfoSection: some View {
        SectionCard(title: "") {
            VStack(alignment: .leading, spacing: 16) {
                // Header with name and basic info
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.fullName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let jobTitle = user.jobTitle, let company = user.currentCompany {
                            Text("\(jobTitle) at \(company)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        } else if let jobTitle = user.jobTitle {
                            Text(jobTitle)
                                .font(.headline)
                                .foregroundColor(.blue)
                        } else if let company = user.currentCompany {
                            Text("Works at \(company)")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        
                        if let location = user.location {
                            Label(location, systemImage: "location.fill")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    UserAvatar(user: user, size: 80)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // Personal details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Details")
                        .font(.headline)
                        .padding(.vertical, 4)
                    
                    Group {
                        if let gender = user.gender {
                            InfoRow(icon: "person.fill", title: "Gender", value: gender)
                        }
                        
                        if let ethnicity = user.ethnicity {
                            InfoRow(icon: "person.2.fill", title: "Ethnicity", value: ethnicity)
                        }
                        
                        if let email = user.email {
                            InfoRow(icon: "envelope.fill", title: "Email", value: email)
                        }
                        
                        if let phone = user.phoneNumber {
                            InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                        }
                    }
                }
                
                Divider()
                
                // Education and work
                VStack(alignment: .leading, spacing: 12) {
                    Text("Education & Work")
                        .font(.headline)
                        .padding(.vertical, 4)
                    
                    Group {
                        if let university = user.university {
                            InfoRow(icon: "building.columns.fill", title: "University", value: university)
                        }
                        
                        if let major = user.uniMajor {
                            InfoRow(icon: "book.fill", title: "Major", value: major)
                        }
                        
                        if let highSchool = user.highSchool {
                            InfoRow(icon: "graduationcap.fill", title: "High School", value: highSchool)
                        }
                        
                        if let interests = user.fieldOfInterest {
                            InfoRow(icon: "star.fill", title: "Interests", value: interests)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture {
            showingEditContactSheet = true
        }
        .sheet(isPresented: $showingEditContactSheet) {
            EditProfileView(user: user)
        }
    }
    
    /// Displays the user's connections with an option to add new connections
    private var connectionsSection: some View {
        SectionCard(title: "Connections") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    
                    Button(action: {
                        showingAddConnectionSheet = true
                    }) {
                        Label("Add Connection", systemImage: "plus")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 4)
                
                VStack {
                    if coordinator.networkManager.isLoading && connectionLoadAttempts < 3 {
                        Text("Loading connections...")
                            .foregroundColor(.gray)
                            .frame(height: 120)
                            .frame(maxWidth: .infinity)
                    } else if !localConnections.isEmpty {
                        ForEach(localConnections) { connection in
                            ConnectionRow(connection: connection, onRemove: {
                                removeConnection(connection)
                            })
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("No connections found")
                                .foregroundColor(.gray)
                                .padding()
                            
                            Button(action: {
                                forceShowEmptyState = false
                                loadConnections(forceReload: true)
                            }) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Requests user connections from the network manager
    /// - Parameter forceReload: Whether to force a reload of connections
    private func loadConnections(forceReload: Bool = false) {
        if forceReload {
            connectionLoadAttempts = 0
            forceShowEmptyState = false
        }
        
        connectionLoadAttempts += 1
        
        // Clear any error message before fetching
        coordinator.networkManager.errorMessage = nil
        
        // Get connections (async operation)
        coordinator.networkManager.getConnections(userId: user.id)
        
        // Force the view to check connections after a delay in case something goes wrong
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.localConnections.isEmpty && !self.coordinator.networkManager.isLoading {
                self.updateLocalConnections()
                
                // If still empty and not loading, force show empty state
                if self.localConnections.isEmpty && !self.coordinator.networkManager.isLoading {
                    self.forceShowEmptyState = true
                }
            }
        }
    }
    
    /// Updates the local connections from the network manager
    private func updateLocalConnections() {
        localConnections = coordinator.networkManager.connections
        
        // Force UI update if needed
        if !localConnections.isEmpty {
            // Reset the force state since we have connections
            forceShowEmptyState = false
        }
    }
    
    /// Sets up timers to retry loading connections if initial attempts fail
    private func setupConnectionLoadTimers() {
        // Clean up any existing timer
        retryTimer?.invalidate()
        
        // Set up a retry timer if connections are empty
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.localConnections.isEmpty && self.connectionLoadAttempts < 3 && !self.forceShowEmptyState {
                self.loadConnections()
            } else {
                // Stop retrying after success or 3 attempts
                self.retryTimer?.invalidate()
                self.retryTimer = nil
            }
        }
    }
    
    /// Removes a connection between the current user and the specified connection
    /// - Parameter connection: The connection to remove
    private func removeConnection(_ connection: Connection) {
        // Call API to remove connection
        coordinator.networkManager.removeConnection(userId: user.id, connectionId: connection.id) { success in
            if success {
                // Reload connections on success
                self.loadConnections(forceReload: true)
            }
        }
    }
}

// MARK: - Connection Row

/// A row displaying a single connection with options to view details or remove
struct ConnectionRow: View {
    let connection: Connection
    let onRemove: () -> Void
    @State private var showingRemoveAlert = false
    
    var body: some View {
        HStack {
            let userForAvatar = User(
                id: connection.id,
                username: connection.username,
                firstName: connection.firstName,
                lastName: connection.lastName,
                email: connection.email,
                phoneNumber: connection.phoneNumber,
                location: connection.location,
                university: connection.university,
                fieldOfInterest: connection.fieldOfInterest,
                highSchool: connection.highSchool,
                birthday: nil,
                createdAt: nil,
                currentCompany: nil,
                gender: connection.gender,
                ethnicity: connection.ethnicity,
                uniMajor: connection.uniMajor,
                jobTitle: connection.jobTitle
            )
            UserAvatar(user: userForAvatar, size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.fullName)
                    .fontWeight(.semibold)
                
                if let description = connection.relationshipDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingRemoveAlert = true
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .alert("Remove Connection", isPresented: $showingRemoveAlert, presenting: connection) { _ in
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: { _ in
            Text("Are you sure you want to remove this connection?")
        }
    }
}

// MARK: - Add Connection View

/// View for adding a new connection to a user
struct AddConnectionView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    let userId: Int
    @State private var selectedUser: User? = nil
    @State private var description = ""
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select a user")) {
                    Picker("User", selection: $selectedUser) {
                        Text("Select a user").tag(nil as User?)
                        
                        ForEach(filteredUsers) { user in
                            Text(user.fullName).tag(user as User?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section(header: Text("Relationship")) {
                    TextField("How do you know this person?", text: $description)
                }
                
                Section {
                    Button("Add Connection") {
                        addConnection()
                    }
                    .disabled(selectedUser == nil)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(selectedUser == nil ? .gray : .blue)
                }
            }
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    /// Filters users to show only those that aren't the current user or the viewed user
    private var filteredUsers: [User] {
        guard let currentUserId = coordinator.networkManager.userId else {
            return []
        }
        
        return coordinator.networkManager.users.filter { user in
            // Filter out:
            // 1. Current user
            // 2. The user whose detail we're viewing
            // 3. Filter by search text if any
            let nameMatch = searchText.isEmpty || 
                           user.fullName.lowercased().contains(searchText.lowercased())
            
            return user.id != currentUserId && 
                   user.id != userId &&
                   nameMatch
        }
    }
    
    /// Adds a connection between the current user and the selected user
    private func addConnection() {
        guard let selectedUser = selectedUser else { return }
        
        coordinator.networkManager.addConnection(
            userId: userId, 
            connectionId: selectedUser.id, 
            relationshipType: description, 
            completion: { success in
                if success {
                    dismiss()
                }
            }
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        UserDetailView(user: User(
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
} 