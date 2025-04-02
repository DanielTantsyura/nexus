import SwiftUI

/// View that displays the user's connections
struct NetworkView: View {
    // MARK: - Environment
    
    /// Reference to the app coordinator
    @EnvironmentObject var coordinator: AppCoordinator
    
    // MARK: - State
    
    /// Search text for filtering connections
    @State private var searchText = ""
    
    // MARK: - View
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Content based on state
                if coordinator.networkManager.isLoading {
                    LoadingView(message: "Loading connections...")
                } else if let errorMessage = coordinator.networkManager.errorMessage {
                    ErrorView(message: errorMessage) {
                        coordinator.networkManager.fetchUserConnections()
                    }
                } else if filteredConnections.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "No connections found",
                        message: !searchText.isEmpty ? "Try a different search term" : "Add connections to build your network",
                        buttonTitle: "Add Contact",
                        action: { coordinator.showCreateContact() }
                    )
                } else {
                    // Connection list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConnections) { connection in
                                VStack(spacing: 0) {
                                    connectionRow(connection)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectConnection(connection)
                                        }
                                        .padding(.horizontal)
                                    
                                    if connection.id != filteredConnections.last?.id {
                                        Divider()
                                            .padding(.leading)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        coordinator.networkManager.fetchUserConnections()
                    }
                }
            }
            .navigationTitle("My Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        coordinator.showCreateContact()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                coordinator.activeScreen = .userList
                coordinator.networkManager.fetchUserConnections()
            }
        }
    }
    
    // MARK: - UI Components
    
    /// Search bar for filtering connections
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search connections...", text: $searchText)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Row for displaying a single connection
    private func connectionRow(_ connection: Connection) -> some View {
        HStack(spacing: 12) {
            // Avatar
            UserAvatar(user: createUserFromConnection(connection), size: 50)
            
            // User details
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(connection.fullName)
                    .font(.headline)
                
                // Relationship description
                if let description = connection.relationshipDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Tags (if available)
                if let tags = connection.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(3), id: \.self) { tag in
                                TagBadge(text: tag, showRemoveButton: false)
                            }
                            
                            if tags.count > 3 {
                                Text("+\(tags.count - 3)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .frame(height: 24)
                }
                
                // Job title and company
                if let jobTitle = connection.jobTitle {
                    Text(jobTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Navigation indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    
    /// Returns filtered connections based on search text
    private var filteredConnections: [Connection] {
        if searchText.isEmpty {
            return coordinator.networkManager.connections
        } else {
            return coordinator.networkManager.connections.filter { connection in
                let name = connection.fullName.lowercased()
                let description = connection.relationshipDescription?.lowercased() ?? ""
                let company = connection.currentCompany?.lowercased() ?? ""
                let tags = connection.tags?.joined(separator: " ").lowercased() ?? ""
                let searchLower = searchText.lowercased()
                
                return name.contains(searchLower) ||
                       description.contains(searchLower) ||
                       company.contains(searchLower) ||
                       tags.contains(searchLower)
            }
        }
    }
    
    /// Creates a User object from connection data for avatar display
    private func createUserFromConnection(_ connection: Connection) -> User {
        User(
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
            currentCompany: connection.currentCompany,
            gender: connection.gender,
            ethnicity: connection.ethnicity,
            uniMajor: connection.uniMajor,
            jobTitle: connection.jobTitle,
            lastLogin: nil,
            profileImageUrl: connection.profileImageUrl,
            linkedinUrl: connection.linkedinUrl,
            recentTags: nil
        )
    }
    
    /// Selects a connection and navigates to user detail
    private func selectConnection(_ connection: Connection) {
        coordinator.networkManager.fetchUser(withId: connection.id) { result in
            switch result {
            case .success(let user):
                coordinator.showUserDetail(user)
            case .failure(let error):
                coordinator.networkManager.errorMessage = "Failed to load user: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Environment Values

/// Custom environment key for controlling swipe navigation gestures
struct SwipeNavigationGestureKey: EnvironmentKey {
    /// Default value for the swipe gesture (enabled by default)
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    /// Controls whether swipe navigation gestures are enabled
    var swipeNavigationGestureEnabled: Bool {
        get { self[SwipeNavigationGestureKey.self] }
        set { self[SwipeNavigationGestureKey.self] = newValue }
    }
}

// MARK: - Preview

#Preview {
    NetworkView()
        .environmentObject(AppCoordinator())
}

