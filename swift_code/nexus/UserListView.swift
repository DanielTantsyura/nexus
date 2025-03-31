import SwiftUI

struct UserListView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBarView
            
            // Content based on state
            contentView
        }
        .onAppear {
            coordinator.activeScreen = .userList
            coordinator.refreshData()
        }
    }
    
    // MARK: - Subviews
    
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search users...", text: $searchText, onCommit: {
                    performSearch()
                })
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
                action: { coordinator.refreshData() }
            )
        } else {
            userListView
        }
    }
    
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
            coordinator.refreshData()
        }
    }
    
    // MARK: - Helper Methods
    
    private var filteredUsers: [User] {
        // Filter out the current user
        guard let currentUserId = coordinator.networkManager.userId else {
            return coordinator.networkManager.users
        }
        
        return coordinator.networkManager.users.filter { user in
            user.id != currentUserId
        }
    }
    
    private func performSearch() {
        if searchText.isEmpty {
            coordinator.refreshData()
        } else {
            coordinator.networkManager.searchUsers(term: searchText)
        }
    }
}

#Preview {
    NavigationView {
        UserListView()
            .environmentObject(AppCoordinator())
    }
} 