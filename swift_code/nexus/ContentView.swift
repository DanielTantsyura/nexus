import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            VStack {
                // Search bar
                searchBarView
                
                // Content based on state
                contentView
            }
            .navigationTitle("Nexus Network")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        coordinator.refreshData()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(user: user)
            }
        }
        .onAppear {
            coordinator.refreshData()
        }
    }
    
    // MARK: - Subviews
    
    private var searchBarView: some View {
        HStack {
            TextField("Search users...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onSubmit {
                    performSearch()
                }
            
            Button(action: {
                performSearch()
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.trailing)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if coordinator.networkManager.isLoading && !coordinator.initialLoadComplete {
            loadingView
        } else if let errorMessage = coordinator.networkManager.errorMessage {
            errorView(errorMessage)
        } else if coordinator.networkManager.users.isEmpty {
            emptyStateView
        } else {
            userListView
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading users...")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Text("Error")
                .font(.headline)
                .foregroundColor(.red)
            
            Text(message)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Retry") {
                coordinator.refreshData()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "person.3")
                .font(.system(size: 50))
                .foregroundColor(.gray)
                .padding()
            
            Text("No users found")
                .font(.headline)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            
            Button("Refresh") {
                coordinator.refreshData()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var userListView: some View {
        List(coordinator.networkManager.users) { user in
            UserListRow(user: user)
                .onTapGesture {
                    coordinator.showUserDetail(user: user)
                }
        }
        .refreshable {
            coordinator.refreshData()
        }
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        if searchText.isEmpty {
            coordinator.refreshData()
        } else {
            coordinator.networkManager.searchUsers(term: searchText)
        }
    }
}

// MARK: - User List Row
struct UserListRow: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(user.fullName)
                .font(.headline)
            Text(user.university ?? "No university")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - User Detail View
struct UserDetailView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let user: User
    @State private var showingAddConnectionSheet = false
    @State private var connectionLoadAttempts = 0
    @State private var localConnections: [Connection] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // User info section
                userInfoSection
                
                // Contact info section
                contactInfoSection
                
                // Connections section
                connectionsSection
            }
            .padding()
        }
        .navigationTitle("Profile")
        .onAppear {
            coordinator.activeScreen = .userDetail
            loadConnections(forceReload: true)
            
            // Set up timers for connection loading
            setupConnectionLoadTimers()
        }
        .onChange(of: user.id) { 
            loadConnections(forceReload: true)
        }
        .onChange(of: coordinator.networkManager.connections) { 
            updateLocalConnections()
        }
        .sheet(isPresented: $showingAddConnectionSheet, onDismiss: {
            loadConnections(forceReload: true)
        }) {
            AddConnectionView(userId: user.id)
        }
    }
    
    // MARK: - Subviews
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(user.fullName)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(user.university ?? "No university")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text(user.location ?? "No location")
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Information")
                .font(.headline)
            
            HStack {
                Image(systemName: "envelope")
                Text(user.email ?? "No email")
            }
            
            HStack {
                Image(systemName: "phone")
                Text(user.phoneNumber ?? "No phone number")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with actions
            HStack {
                Text("Connections (\(localConnections.count))")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    loadConnections(forceReload: true)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    showingAddConnectionSheet = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            // Connection content
            connectionContentView
            
            // Help text
            if !localConnections.isEmpty {
                Text("Tap refresh if connections don't appear")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var connectionContentView: some View {
        if coordinator.networkManager.isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .padding()
                Spacer()
            }
        } else if localConnections.isEmpty {
            Text("No connections found")
                .foregroundColor(.gray)
                .padding(.vertical, 8)
                .onTapGesture {
                    loadConnections(forceReload: true)
                }
        } else {
            connectionsList
        }
    }
    
    private var connectionsList: some View {
        ForEach(localConnections) { connection in
            HStack {
                Text(connection.fullName)
                    .fontWeight(.semibold)
                Spacer()
                Text(connection.relationshipDescription ?? "Unknown relationship")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Button(action: {
                    coordinator.networkManager.removeConnection(
                        userId: user.id,
                        connectionId: connection.id
                    ) { _ in
                        loadConnections(forceReload: true)
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
            Divider()
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupConnectionLoadTimers() {
        // Set up a timer to check if connections were loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.localConnections.isEmpty && !self.coordinator.networkManager.isLoading {
                self.loadConnections(forceReload: true)
            }
        }
        
        // Set up a second timer for a final check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.updateLocalConnections()
            if self.localConnections.isEmpty && self.coordinator.networkManager.connections.count > 0 {
                self.updateLocalConnections()
            }
        }
    }
    
    private func loadConnections(forceReload: Bool) {
        if forceReload || coordinator.networkManager.connections.isEmpty {
            connectionLoadAttempts += 1
            coordinator.networkManager.getConnections(userId: user.id)
            
            // Update after a short delay to ensure refresh
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateLocalConnections()
            }
        }
    }
    
    private func updateLocalConnections() {
        let connections = coordinator.networkManager.connections
        localConnections = connections
    }
}

// MARK: - Add Connection View
struct AddConnectionView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    let userId: Int
    @State private var searchText = ""
    @State private var selectedUserId: Int?
    @State private var relationshipType = "Friend"
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var connectionAdded = false
    
    private let relationshipTypes = ["Friend", "Colleague", "Classmate", "Family", "Business"]
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                searchBarView
                
                // Content based on state
                contentView
                
                Spacer()
            }
            .navigationTitle("Add Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // If a connection was added, make sure to refresh parent view
                        if connectionAdded {
                            coordinator.networkManager.getConnections(userId: userId)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Fetch all users when the view appears
                coordinator.networkManager.fetchUsers()
                hasSearched = true
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBarView: some View {
        VStack {
            TextField("Search for users", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onSubmit {
                    performSearch()
                }
            
            Button("Search") {
                performSearch()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if coordinator.networkManager.isLoading {
            ProgressView()
                .padding()
        } else if coordinator.networkManager.users.isEmpty {
            emptyStateView
        } else {
            userSelectionView
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
                .padding()
            
            Text("No users found")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Try a different search term")
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var userSelectionView: some View {
        VStack {
            userListView
            
            if selectedUserId != nil {
                relationshipSelectionView
            }
        }
    }
    
    private var userListView: some View {
        List {
            ForEach(coordinator.networkManager.users.filter { $0.id != userId }) { user in
                HStack {
                    VStack(alignment: .leading) {
                        Text(user.fullName)
                            .font(.headline)
                        Text(user.university ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if selectedUserId == user.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedUserId = user.id
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var relationshipSelectionView: some View {
        VStack {
            Picker("Relationship Type", selection: $relationshipType) {
                ForEach(relationshipTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            
            addConnectionButton
        }
    }
    
    private var addConnectionButton: some View {
        Button(action: {
            addConnection()
        }) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.horizontal)
            } else {
                Text("Add Connection")
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
        .padding()
        .disabled(isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        if searchText.isEmpty {
            coordinator.networkManager.fetchUsers()
        } else {
            coordinator.networkManager.searchUsers(term: searchText)
        }
        hasSearched = true
    }
    
    private func addConnection() {
        isLoading = true
        if let connectionId = selectedUserId {
            coordinator.networkManager.addConnection(
                userId: userId,
                connectionId: connectionId,
                relationshipType: relationshipType
            ) { success in
                isLoading = false
                if success {
                    connectionAdded = true
                    // Force a reload of connections in the parent view before dismissing
                    coordinator.networkManager.getConnections(userId: userId)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
            }
        }
    }
}
