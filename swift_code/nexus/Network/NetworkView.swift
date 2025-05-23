import SwiftUI
import UIKit
import Combine

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
    
    /// State for managing multiple tag filters
    @State private var selectedTags: Set<String> = []
    
    /// State to control visibility of the tag selection interface
    @State private var showTagSelector: Bool = false
    
    /// Toggle to force UI refresh
    @State private var refreshTrigger = false
    
    /// Track if we've shown connections already
    @State private var hasShownConnections = false
    
    /// State to manage the delete confirmation dialog
    @State private var showDeleteConfirmation = false
    
    /// The connection being considered for deletion
    @State private var connectionToDelete: Connection? = nil
    
    /// Cancellable for refresh signal subscription
    @State private var refreshCancellable: AnyCancellable?
    
    /// Computed property for filtered connections based on search text and selected tag
    private var filteredConnections: [Connection] {
        let connections = coordinator.networkManager.connections
        
        // If no search text or tag filter, return all connections
        if searchText.isEmpty && selectedTags.isEmpty {
            return connections
        }
        
        return connections.filter { connection in
            // Filter by search text
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                // Search in multiple fields
                let searchableText = [
                    connection.user.firstName,
                    connection.user.lastName,
                    connection.user.jobTitle,
                    connection.user.currentCompany,
                    connection.user.university,
                    connection.user.location,
                    connection.user.fieldOfInterest,
                    connection.relationshipDescription,
                    connection.notes
                ].compactMap { $0 }.joined(separator: " ").lowercased()
                
                matchesSearch = searchableText.contains(searchText.lowercased())
            }
            
            // Filter by tags (intersection)
            let matchesTags: Bool
            if selectedTags.isEmpty {
                matchesTags = true
            } else {
                // Make sure connection has all selected tags (intersection)
                // Convert array to Set before checking isSuperset
                if let tags = connection.tags {
                    let tagsSet = Set(tags)
                    matchesTags = tagsSet.isSuperset(of: selectedTags)
                } else {
                    matchesTags = false
                }
            }
            
            return matchesSearch && matchesTags
        }
    }
    
    /// List of available tag options for filtering
    private var tagOptions: [String] {
        // Get unique tags from all connections
        var allTags = Set<String>()
        
        for connection in coordinator.networkManager.connections {
            if let tags = connection.tags {
                tags.forEach { allTags.insert($0) }
            }
        }
        
        // Sort tags alphabetically
        return ["All"] + allTags.sorted()
    }
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App header
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                ) {
                    // Plus button removed
                    EmptyView()
                }
                
                // Search bar with tag filter
                HStack(spacing: 8) {
                    // Search field that stretches
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 4)
                        TextField("Search", text: $searchText)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
                
                    // Right-side buttons with fixed widths
                    HStack(spacing: 8) {
                        // Tags button with fixed width
                        Button(action: {
                            withAnimation {
                                showTagSelector.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(selectedTags.isEmpty ? "Tags" : "\(selectedTags.count)")
                                    .font(.subheadline)
                                Image(systemName: showTagSelector ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedTags.isEmpty ? Color.green.opacity(0.1) : Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        .fixedSize()
                        
                        // Clear button with fixed width
                        if !searchText.isEmpty || !selectedTags.isEmpty {
                            Button(action: {
                                searchText = ""
                                selectedTags = []
                                showTagSelector = false
                            }) {
                                Text("Clear")
                                    .font(.subheadline)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                            .fixedSize()
                        }
                    }
                }
                .padding(.horizontal, 0)
                
                // Tag selector
                if showTagSelector {
                    // Container for tags
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Select tags (showing connections with ALL selected tags)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 2)
                        
                        // Scrollable tag grid
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: [
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8),
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8),
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8)
                            ], spacing: 8) {
                                ForEach(tagOptions.filter { $0 != "All" }, id: \.self) { tag in
                                    // Individual tag button
                                    Button(action: {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }) {
                                        Text(tag)
                                            .font(.system(size: 11))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(selectedTags.contains(tag) 
                                                ? tagColor(for: tag).opacity(0.3)
                                                : tagColor(for: tag).opacity(0.1))
                                            .foregroundColor(selectedTags.contains(tag)
                                                ? tagColor(for: tag)
                                                : tagColor(for: tag).opacity(0.8))
                                            .cornerRadius(14)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(tagColor(for: tag).opacity(selectedTags.contains(tag) ? 0.5 : 0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 100)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .transition(.opacity)
                    .onTapGesture {} // Prevent taps from passing through
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in }
                    ) // Prevent taps from passing through
                }
                
                // Search results counter - Always show and more compact
                HStack {
                    if !searchText.isEmpty || !selectedTags.isEmpty {
                        Text("\(filteredConnections.count) connection\(filteredConnections.count == 1 ? "" : "s") found")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(filteredConnections.count) connection\(filteredConnections.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.top, 0)
                .padding(.bottom, 0)
                
                // Main content
                connectionsList
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            // Always load connections when the view appears, but avoid duplicate loads
            if !coordinator.networkManager.isLoading {
                refreshConnections()
                
                // Force a refresh when the view first appears to ensure UI is updated
                if !hasShownConnections && !coordinator.networkManager.connections.isEmpty {
                    hasShownConnections = true
                    refreshTrigger.toggle()
                }
            }
            
            // Listen for refresh signals from the NetworkManager
            refreshCancellable = coordinator.networkManager.$refreshSignal
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    // Check which type of refresh occurred
                    let refreshType = coordinator.networkManager.lastRefreshType
                    
                    // Only refresh UI if it's relevant to connections
                    if refreshType == .connections || refreshType == .profile {
                        // If we have connections data but haven't shown it yet, update the UI
                        if !coordinator.networkManager.connections.isEmpty && !hasShownConnections {
                            hasShownConnections = true
                            refreshTrigger.toggle()
                        }
                    }
                }
        }
        .refreshable {
            await refreshConnectionsAsync()
        }
        .onChange(of: coordinator.networkManager.connections) { oldValue, connections in
            // Force a refresh when we get non-zero connections for the first time
            if !connections.isEmpty && !hasShownConnections {
                hasShownConnections = true
                refreshTrigger.toggle()
            }
        }
        .id(refreshTrigger) // Re-add the ID modifier to allow forcing refresh when needed
        .confirmationDialog(
            "Delete Contact",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let connection = connectionToDelete {
                    deleteConnection(connection)
                }
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
                connectionToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
        }
        .dismissKeyboardOnTap()
        .onTapGesture {
            // Close tag selector if open
            if showTagSelector {
                withAnimation {
                    showTagSelector = false
                }
            }
        }
        .onDisappear {
            refreshCancellable?.cancel()
        }
    }
    
    // MARK: - UI Components
    
    /// List of connections
    private var connectionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if filteredConnections.isEmpty && !coordinator.networkManager.isLoading {
                if coordinator.networkManager.connections.isEmpty {
                    emptyState
                } else {
                    // No results from search
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results Found",
                        message: "No connections match your current search. Try adjusting your search terms or clear filters.",
                        buttonTitle: "Clear Filters",
                        action: {
                            searchText = ""
                            selectedTags = []
                            showTagSelector = false
                        }
                    )
                }
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
        VStack(alignment: .leading, spacing: 10) {
            // Show connections
            ForEach(filteredConnections) { connection in
                connectionCard(for: connection)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.showContact(connection.user)
                    }
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
                    VStack(alignment: .leading, spacing: 1) { // Reduced spacing from 2 to 1
                        // Name - first line that extends fully without abbreviation
                        Text(connection.user.fullName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1) // Reduced from 2 to 1
                        
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
                        
                        // Contact buttons - 25% larger with symbols only, in order: message, call, linkedin, email
                        HStack(spacing: 8) {
                            // Text Message button (iMessage green)
                            if let phone = connection.user.phoneNumber, !phone.isEmpty {
                                Button(action: {
                                    let formattedPhone = phone.replacingOccurrences(of: " ", with: "")
                                    if let url = URL(string: "sms:\(formattedPhone)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 0.0))
                                        .padding(5)
                                        .background(Color(red: 0.0, green: 0.8, blue: 0.0).opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            
                            // Call button
                            if let phone = connection.user.phoneNumber, !phone.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: " ", with: ""))") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .padding(5)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            
                            // LinkedIn button - opens LinkedIn profile if URL exists
                            if let linkedInUrl = connection.user.linkedinUrl, !linkedInUrl.isEmpty {
                                Button(action: {
                                    if let url = URL(string: linkedInUrl) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    ZStack {
                                        Rectangle()
                                            .fill(Color(red: 0.0, green: 0.47, blue: 0.71).opacity(0.1))
                                            .frame(width: 22, height: 22)
                                            .cornerRadius(4)
                                            
                                        Text("in")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color(red: 0.0, green: 0.47, blue: 0.71))
                                    }
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                            
                            // Email button
                            if let email = connection.user.email, !email.isEmpty {
                                Button(action: {
                                    if let url = URL(string: "mailto:\(email)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.87, green: 0.11, blue: 0.11))
                                        .padding(5)
                                        .background(Color(red: 0.87, green: 0.11, blue: 0.11).opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.top, 0) // No padding on top
                        .padding(.bottom, 0) // No padding on bottom
                    }
                }
                .layoutPriority(1)
                
                Spacer(minLength: 0)
                
                // Right side: Tags
                if let tags = connection.tags, !tags.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        // Show max 4 tags in a single column with ellipsis if more
                        let displayTags = tags.count > 4 
                            ? Array(tags.prefix(3)) + ["..."] 
                            : tags
                        
                        ForEach(displayTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .padding(.horizontal, 4) // Reduced from 8 to 4
                                .padding(.vertical, 4)
                                .background(tag == "..." 
                                    ? Color.gray.opacity(0.2) 
                                    : tagColor(for: tag).opacity(0.2))
                                .foregroundColor(tag == "..." 
                                    ? Color.gray 
                                    : tagColor(for: tag))
                                .cornerRadius(6)
                                .lineLimit(1)
                                .frame(maxWidth: 70) // Reduced from 80 to 70
                        }
                        .padding(.trailing, -2) // Reduced from -4 to -2
                    }
                    .frame(width: 75) // Reduced from 85 to 75
                    .layoutPriority(0)
                }
            }
            .padding(.vertical, 2) // Reduced vertical padding from 4 to 2
            .padding(.horizontal, 0)
        }
        .padding(.horizontal, 0)
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
        
        // Allow showing connections again after a manual refresh
        if !coordinator.networkManager.connections.isEmpty {
            hasShownConnections = false
        }
        
        coordinator.networkManager.fetchConnections(forUserId: coordinator.networkManager.userId ?? 0)
        
        // Add a delay to update UI after fetch completes
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // If connections loaded successfully and we haven't shown them yet
            if !coordinator.networkManager.connections.isEmpty && !hasShownConnections {
                hasShownConnections = true
                refreshTrigger.toggle()
            }
        }
    }
    
    /// Refreshes the list of connections (async version for pull-to-refresh)
    private func refreshConnectionsAsync() async {
        isRefreshing = true
        
        // Allow showing connections again after a pull-to-refresh
        hasShownConnections = false
        
        // Call the refresh function
        coordinator.networkManager.fetchConnections(forUserId: coordinator.networkManager.userId ?? 0)
        
        // Add a delay to allow data to load
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        isRefreshing = false
        // We only toggle the refreshTrigger during manual pull-to-refresh
        refreshTrigger.toggle() 
    }
    
    /// Delete a connection
    private func deleteConnection(_ connection: Connection) {
        coordinator.networkManager.deleteContact(contactId: connection.id) { result in
            switch result {
            case .success(true):
                // The connection list will be updated automatically by the NetworkManager
                // We can add additional feedback if desired
                print("Successfully deleted connection to \(connection.user.fullName)")
            case .failure:
                // Handle error - could show an alert here
                print("Failed to delete connection to \(connection.user.fullName)")
            default:
                break
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
