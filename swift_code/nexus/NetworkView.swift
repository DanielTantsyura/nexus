import SwiftUI

/// A view displaying the user's network connections
struct NetworkView: View {
    // MARK: - Properties
    
    /// App coordinator for navigation and state management
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// State for controlling the refresh of connections
    @State private var isRefreshing = false
    
    /// Error message to display
    @State private var errorMessage: String? = nil
    
    /// State for managing the search functionality
    @State private var searchText: String = ""
    
    /// State for managing the tag filter
    @State private var selectedTag: String? = nil
    
    /// List of available tag options for filtering
    private let tagOptions: [String] = ["All", "Tag1", "Tag2", "Tag3"]
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App header
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                ) {
                    Button(action: {
                        coordinator.selectedTab = .addNew
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                    }
                }
                
                // Error message
                if let errorMessage = errorMessage {
                    errorBanner(message: errorMessage)
                }
                
                // Search bar with tag filter
                HStack(spacing: 8) {
                    // Search field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        TextField("Search...", text: $searchText)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .layoutPriority(3)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    
                    // Tag dropdown
                    Menu {
                        ForEach(tagOptions, id: \.self) { tag in
                            Button(action: {
                                selectedTag = tag == "All" ? nil : tag
                            }) {
                                HStack {
                                    Text(tag)
                                    if tag == (selectedTag ?? "All") {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedTag ?? "Tag")
                            Image(systemName: "chevron.up.chevron.down")
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    .layoutPriority(1)
                    .fixedSize()
                    
                    // Search button
                    Button(action: {
                        performSearch()
                    }) {
                        Text("Search")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .layoutPriority(1)
                    .frame(width: 80)
                }
                .padding(.horizontal, 0)
                
                // Main content
                connectionsList
            }
            .padding()
        }
        .navigationBarHidden(true)
        .overlay(
            Group {
                if coordinator.networkManager.isLoading {
                    LoadingView(message: "Loading connections...")
                }
            }
        )
        .onAppear {
            refreshConnections()
        }
        .refreshable {
            await refreshConnectionsAsync()
        }
    }
    
    // MARK: - UI Components
    
    /// List of connections
    private var connectionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if coordinator.networkManager.connections.isEmpty && !coordinator.networkManager.isLoading {
                emptyState
            } else {
                connectionListContent
            }
        }
    }
    
    /// Error banner displayed at the top of the view
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    errorMessage = nil
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.red)
        .cornerRadius(8)
    }
    
    /// Empty state view when no connections exist
    private var emptyState: some View {
        EmptyStateView(
            icon: "person.3",
            title: "No Connections Yet",
            message: "You haven't added any connections to your network yet. Start building your network by adding your first contact.",
            buttonTitle: "Refresh",
            action: refreshConnections
        )
    }
    
    /// Content displayed when connections exist
    private var connectionListContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            ForEach(coordinator.networkManager.connections) { connection in
                connectionCard(for: connection)
            }
        }
    }
    
    /// Card displaying a connection's informationssds
    private func connectionCard(for connection: Connection) -> some View {
        SectionCard(title: "") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    // Avatar
                    UserAvatar(user: connection.user, size: 60)
                    
                    // User details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection.user.fullName)
                            .font(.headline)
                        
                        if let title = connection.user.jobTitle, !title.isEmpty {
                            HStack(spacing: 4) {
                                Text(title)
                                if let company = connection.user.currentCompany, !company.isEmpty {
                                    Text("•")
                                    Text(company)
                                }
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        
                        if let university = connection.user.university, !university.isEmpty {
                            Text(university)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                    
                    // View details button
                    Button(action: {
                        coordinator.showUserDetail(connection.user)
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                if !connection.tags.isEmpty {
                    tagsList(tags: connection.tags)
                }
            }
        }
        .onTapGesture {
            coordinator.showUserDetail(connection.user)
        }
    }
    
    /// Horizontal scrolling list of tags
    private func tagsList(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Methods
    
    /// Refreshes the list of connections (non-async version)
    private func refreshConnections() {
        errorMessage = nil
        coordinator.networkManager.fetchConnections(forUserId: coordinator.networkManager.userId ?? 0)
    }
    
    /// Refreshes the list of connections (async version for pull-to-refresh)
    private func refreshConnectionsAsync() async {
        isRefreshing = true
        
        await withCheckedContinuation { continuation in
            refreshConnections()
            continuation.resume()
        }
        
        isRefreshing = false
    }
    
    /// Performs a search based on the current search text and tag filter
    private func performSearch() {
        // Implementation of performSearch method
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

