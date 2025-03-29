import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack(path: $coordinator.navigationPath) {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Search bar
                searchBarView
                
                // Content based on state
                contentView
            }
            .navigationBarHidden(true)
            .navigationDestination(for: User.self) { user in
                UserDetailView(user: user)
            }
        }
        .onAppear {
            coordinator.refreshData()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Nexus Network")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    coordinator.refreshData()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            
            Text("Connect with people in your network")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search users...", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        coordinator.refreshData()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: {
                performSearch()
            }) {
                Text("Search")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Loading users...")
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
                .padding()
            
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
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
                .padding()
            
            Text("No users found")
                .font(.headline)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .foregroundColor(.gray)
            } else {
                Text("Refresh to find people")
                    .foregroundColor(.gray)
            }
            
            Button("Refresh") {
                coordinator.refreshData()
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
        }
        .padding()
    }
    
    private var userListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(coordinator.networkManager.users) { user in
                    VStack(spacing: 0) {
                        UserListRow(user: user)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.showUserDetail(user: user)
                            }
                            .padding(.horizontal)
                        
                        if user.id != coordinator.networkManager.users.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
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
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(user.fullName.prefix(1)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    if let university = user.university {
                        Label(university, systemImage: "building.columns")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if let location = user.location {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                if let jobTitle = user.jobTitle, let company = user.currentCompany {
                    Text("\(jobTitle) at \(company)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let jobTitle = user.jobTitle {
                    Text(jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
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
                    showingAddConnectionSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
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
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(user.fullName.prefix(1)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.blue)
                    )
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
                        infoRow(icon: "person.fill", title: "Gender", value: gender)
                    }
                    
                    if let ethnicity = user.ethnicity {
                        infoRow(icon: "globe", title: "Ethnicity", value: ethnicity)
                    }
                    
                    if let email = user.email {
                        infoRow(icon: "envelope.fill", title: "Email", value: email)
                    }
                    
                    if let phone = user.phoneNumber {
                        infoRow(icon: "phone.fill", title: "Phone", value: phone)
                    }
                }
            }
            
            Divider()
            
            // Education
            VStack(alignment: .leading, spacing: 12) {
                Text("Education")
                    .font(.headline)
                    .padding(.vertical, 4)
                
                Group {
                    if let university = user.university {
                        infoRow(icon: "building.columns.fill", title: "University", value: university)
                    }
                    
                    if let major = user.uniMajor {
                        infoRow(icon: "book.fill", title: "Major", value: major)
                    }
                    
                    if let highSchool = user.highSchool {
                        infoRow(icon: "building.2.fill", title: "High School", value: highSchool)
                    }
                }
            }
            
            Divider()
            
            // Interests
            if let interests = user.fieldOfInterest {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interests")
                        .font(.headline)
                        .padding(.vertical, 4)
                    
                    Text(interests)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Interest tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(interests.components(separatedBy: ", "), id: \.self) { interest in
                                Text(interest)
                                    .font(.caption)
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private var contactInfoSection: some View {
        EmptyView()
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
            VStack(spacing: 12) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 8)
                
                Text("No connections found")
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onTapGesture {
                loadConnections(forceReload: true)
            }
        } else {
            connectionsList
        }
    }
    
    private var connectionsList: some View {
        VStack(spacing: 0) {
            ForEach(localConnections) { connection in
                HStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(connection.fullName.prefix(1)))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.blue)
                        )
                    
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
                .padding(.vertical, 12)
                
                if connection.id != localConnections.last?.id {
                    Divider()
                }
            }
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
            VStack(spacing: 0) {
                // Search bar
                VStack(spacing: 16) {
                    Text("Find people to connect with")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.top)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("Search by name, location, university...", text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button("Search") {
                        performSearch()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .background(Color.white)
                
                Divider()
                
                // Content based on state
                if coordinator.networkManager.isLoading {
                    loadingView
                } else if coordinator.networkManager.users.isEmpty {
                    emptyStateView
                } else {
                    userSelectionView
                }
                
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
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            Text("Searching...")
                .foregroundColor(.gray)
            Spacer()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
                .padding()
            
            Text("No users found")
                .font(.headline)
                .foregroundColor(.gray)
            
            if !searchText.isEmpty {
                Text("Try a different search term")
                    .foregroundColor(.gray)
            } else {
                Text("Try searching for someone")
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var userSelectionView: some View {
        VStack(spacing: 0) {
            if selectedUserId != nil {
                relationshipSelectionView
                    .padding()
                    .background(Color.gray.opacity(0.05))
            }
            
            userListView
        }
    }
    
    private var userListView: some View {
        List {
            ForEach(coordinator.networkManager.users.filter { $0.id != userId }) { user in
                HStack {
                    // User avatar
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(user.fullName.prefix(1)))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.blue)
                        )
                    
                    // User info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.fullName)
                            .font(.headline)
                        
                        if let university = user.university {
                            Text(university)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        if let location = user.location {
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                    
                    // Selection indicator
                    if selectedUserId == user.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedUserId = user.id
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var relationshipSelectionView: some View {
        VStack(spacing: 16) {
            Text("What's your relationship?")
                .font(.headline)
            
            Picker("Relationship Type", selection: $relationshipType) {
                ForEach(relationshipTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 4)
            
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
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
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

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
