import SwiftUI

/// View that displays a list of users with search functionality
struct UserListView: View {
    // MARK: - Properties
    
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var searchText = ""
    
    // MARK: - View Body
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            contentView
        }
        .navigationTitle("Users")
        .onAppear {
            coordinator.activeScreen = .userList
            
            // If users is empty, trigger a refresh
            if coordinator.networkManager.users.isEmpty {
                coordinator.refreshData()
                
                // Auto-retry loading users if they're missing
                coordinator.autoRetryLoading(
                    check: { !self.coordinator.networkManager.users.isEmpty },
                    action: { self.coordinator.refreshData() }
                )
            }
            
            print("UserListView appeared, users count: \(coordinator.networkManager.users.count)")
        }
        // Listen for active screen changes which may indicate data refreshes
        .onChange(of: coordinator.activeScreen) { oldValue, newValue in
            if newValue == .userList && filteredUsers.isEmpty && searchText.isEmpty {
                print("Screen changed to userList, refreshing user data")
                coordinator.refreshData()
            }
        }
    }
    
    // MARK: - UI Components
    
    /// Search bar for filtering users
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search by name or location", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        // Reset to all users when clearing search
                        coordinator.networkManager.fetchAllUsers()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if !searchText.isEmpty {
                Button(action: {
                    // Execute search
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
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Main content view that changes based on the current state
    @ViewBuilder
    private var contentView: some View {
        if coordinator.networkManager.isLoading && !coordinator.initialLoadComplete {
            LoadingView(message: "Loading users...")
        } else if let errorMessage = coordinator.networkManager.errorMessage {
            ErrorView(message: errorMessage) {
                coordinator.refreshData()
            }
        } else if filteredUsers.isEmpty {
            EmptyStateView(
                icon: "person.3",
                title: "No users found",
                message: !searchText.isEmpty ? "Try a different search term" : "Refresh to find people",
                buttonTitle: "Refresh",
                action: { 
                    coordinator.refreshData()
                    print("Refreshing user list")
                }
            )
        } else {
            userListView
        }
    }
    
    /// List of users when data is available
    private var userListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredUsers) { user in
                    VStack(spacing: 0) {
                        UserListRow(user: user)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                coordinator.showUserDetail(user: user)
                            }
                            .padding(.horizontal)
                        
                        if user.id != filteredUsers.last?.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable {
            print("Pull-to-refresh triggered")
            coordinator.refreshData()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns a filtered list of users, excluding the current user
    private var filteredUsers: [User] {
        // Filter out the current user
        guard let currentUserId = coordinator.networkManager.userId else {
            return coordinator.networkManager.users
        }
        
        return coordinator.networkManager.users.filter { user in
            user.id != currentUserId
        }
    }
    
    /// Executes a search based on the current search text
    private func performSearch() {
        if searchText.isEmpty {
            coordinator.refreshData()
        } else {
            coordinator.networkManager.searchUsers(term: searchText)
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        UserListView()
            .environmentObject(AppCoordinator())
    }
} 