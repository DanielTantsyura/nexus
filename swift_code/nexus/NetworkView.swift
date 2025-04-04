import SwiftUI
import UIKit

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
    
    /// Card displaying a connection's information
    private func connectionCard(for connection: Connection) -> some View {
        SectionCard(title: "") {
            HStack(alignment: .top, spacing: 4) {
                // Left side: Avatar and user details
                HStack(alignment: .top, spacing: 8) {
                    // Avatar (smaller) with less padding
                    UserAvatar(user: connection.user, size: 50)
                        .padding(.leading, -10) // Further reduce left padding
                    
                    // User details with smaller text and spacing
                    VStack(alignment: .leading, spacing: 2) {
                        // Name - first line that extends fully without abbreviation
                        Text(connection.user.fullName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Job title and company - second line
                        HStack(spacing: 6) {
                            if let jobTitle = connection.user.jobTitle, !jobTitle.isEmpty {
                                Text(jobTitle)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            // Company with icon if available
                            if let company = connection.user.currentCompany, !company.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue.opacity(0.6))
                                    Text(company)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                        
                        // University and location - third line
                        HStack(spacing: 6) {
                            if let university = connection.user.university, !university.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue.opacity(0.7))
                                    Text(abbreviateUniversity(university))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            if let location = connection.user.location, !location.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                    Text(abbreviateLocation(location))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Contact buttons - smaller and more compact
                        HStack(spacing: 10) {
                            if let email = connection.user.email, !email.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "mailto:\(email)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Label("Email", systemImage: "envelope.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let phone = connection.user.phoneNumber, !phone.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Label("Call", systemImage: "phone.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .layoutPriority(1)
                
                Spacer(minLength: 0)
                
                // Right side: Tags
                if !connection.tags.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        // Grid layout for tags with max display and ellipsis
                        let displayTags = connection.tags.count > 8 
                            ? Array(connection.tags.prefix(7)) + ["..."] 
                            : connection.tags
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 42, maximum: 50), spacing: 2)
                            ],
                            alignment: .trailing,
                            spacing: 2
                        ) {
                            ForEach(displayTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(tag == "..." 
                                        ? Color.gray.opacity(0.2) 
                                        : tagColor(for: tag).opacity(0.2))
                                    .foregroundColor(tag == "..." 
                                        ? Color.gray 
                                        : tagColor(for: tag))
                                    .cornerRadius(6)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .frame(width: 90)
                        .layoutPriority(0)
                        .padding(.trailing, -2)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
        }
        .padding(.horizontal, 0)
        .onTapGesture {
            coordinator.showUserDetail(connection.user)
        }
    }
    
    /// Color for tag based on tag name
    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }
    
    /// Abbreviate university names to prevent long text
    private func abbreviateUniversity(_ university: String) -> String {
        let commonAbbreviations = [
            "Massachusetts Institute of Technology": "MIT",
            "Carnegie Mellon University": "CMU",
            "University of California": "UC",
            "University of California, Berkeley": "UC Berkeley",
            "University of California, Los Angeles": "UCLA",
            "California Institute of Technology": "Caltech",
            "Georgia Institute of Technology": "Georgia Tech",
            "Stanford University": "Stanford",
            "Harvard University": "Harvard",
            "Yale University": "Yale",
            "Princeton University": "Princeton",
            "Columbia University": "Columbia",
            "New York University": "NYU"
        ]
        
        if let abbreviation = commonAbbreviations[university] {
            return abbreviation
        }
        
        // If it's already short, return as is
        if university.count <= 12 {
            return university
        }
        
        // Handle "University of X" pattern
        if university.hasPrefix("University of ") {
            let rest = university.dropFirst("University of ".count)
            return "U of " + rest
        }
        
        // Otherwise truncate with ellipsis
        return String(university.prefix(12)) + "..."
    }
    
    /// Abbreviate location names to prevent long text
    private func abbreviateLocation(_ location: String) -> String {
        let usStateAbbreviations = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY"
        ]
        
        // Handle "City, State" pattern - prioritize keeping this format
        let components = location.components(separatedBy: ", ")
        if components.count == 2, let stateAbbr = usStateAbbreviations[components[1]] {
            // For "City, State" format, prioritize keeping it intact
            return components[0] + ", " + stateAbbr
        }
        
        // If it's already short, return as is
        if location.count <= 15 {
            return location
        }
        
        // Otherwise truncate with ellipsis
        return String(location.prefix(15)) + "..."
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

