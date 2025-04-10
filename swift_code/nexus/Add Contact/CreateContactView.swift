import SwiftUI

/// View for creating a new contact with a free-form text entry and tag selection
struct CreateContactView: View {
    // MARK: - Properties
   
    /// App coordinator for navigation and state management
    @EnvironmentObject private var coordinator: AppCoordinator
   
    /// Text content entered by the user
    @State private var contactText = ""
   
    /// New custom tag being created
    @State private var newTagText = ""
   
    /// Collection of tags added to the contact
    @State private var selectedTags: [String] = []
   
    /// Controls focus for different text fields
    @FocusState private var contactTextFieldFocused: Bool
    @FocusState private var tagTextFieldFocused: Bool
   
    /// Error message to display
    @State private var errorMessage: String? = nil
   
    /// Success message to display
    @State private var successMessage: String? = nil
   
    /// Whether a submit operation is in progress
    @State private var isSubmitting = false
   
    /// User created after submitting the form
    @State private var createdUser: User? = nil
    
    /// Filtered tags based on search text
    @State private var filteredTags: [String] = []
    
    /// Recent tags from user's history
    @State private var recentTags: [String] = []
    
    /// All tags ranked by frequency with recent tags first
    @State private var orderedTags: [String] = []
    
    /// Environment access to keyboard dismiss mode
    @Environment(\.keyboardDismissMode) private var keyboardDismissMode
   
    /// Sorted tags based on frequency of use
    private var sortedTags: [String] {
        // Get all connections for the current user
        let connections = coordinator.networkManager.connections
        
        // Count occurrences of each tag
        var tagCounts: [String: Int] = [:]
        
        // Initialize counts for all recent tags to ensure they all appear
        for tag in coordinator.networkManager.recentTags {
            tagCounts[tag] = 0
        }
        
        // Count occurrences in connections
        for connection in connections {
            if let tags = connection.tags {
                for tag in tags {
                    tagCounts[tag, default: 0] += 1
                }
            }
        }
        
        // Sort tags by count (descending)
        return coordinator.networkManager.recentTags.sorted { tag1, tag2 in
            return tagCounts[tag1, default: 0] > tagCounts[tag2, default: 0]
        }
    }
   
    // MARK: - View Body
   
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // App header with checkmark button (replaces X button)
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                ) {
                    Button(action: {
                        submitContact()
                        hideKeyboard()
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                            .padding(12)
                            .background(Circle().fill(contactText.isEmpty ? Color.green.opacity(0.5) : Color.green))
                    }
                    .disabled(contactText.isEmpty)
                }
                .padding(.bottom, 10)
                
                // Error message
                if let errorMessage = errorMessage {
                    errorBanner(message: errorMessage)
                }
               
                // Success message
                if let successMessage = successMessage {
                    successBanner(message: successMessage)
                }
               
                // Contact text area
                contactTextArea
               
                // Selected tags display
                selectedTagsView
               
                // Tag section
                tagSection
               
                // Buttons
                buttonSection
               
                Spacer()
            }
            .padding()
        }
        .dismissKeyboardOnTap()
        .navigationBarHidden(true)
        .onAppear {
            // Fetch tags when the view appears
            loadAllTags()
            fetchRecentTags()
        }
        .disabled(isSubmitting)
        .overlay {
            if isSubmitting {
                LoadingView(message: "Creating contact...")
            }
        }
    }
   
    // MARK: - UI Components
   
    /// Error banner displayed at the top of the form
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
   
    /// Success banner displayed at the top of the form
    private func successBanner(message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
           
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white)
           
            Spacer()
           
            Button(action: {
                withAnimation {
                    successMessage = nil
                }
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.green)
        .cornerRadius(8)
    }
   
    /// Multi-line text entry area for contact information
    private var contactTextArea: some View {
        SectionCard(title: "Create Contact") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $contactText)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .focused($contactTextFieldFocused)
                    .frame(minHeight: 120, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                if contactText.isEmpty {
                    Text("John Smith, Software Engineer at Apple, lives in New York and went to Columbia University...")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    /// View displaying selected tags with delete functionality
    private var selectedTagsView: some View {
        Group {
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Tags")
                        .font(.headline)
                   
                    // Use fixed height container for proper layout
                    VStack(alignment: .leading) {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(selectedTags, id: \.self) { tag in
                                Button(action: {
                                    removeTag(tag)
                                    hideKeyboard()
                                }) {
                                    HStack {
                                        Text(tag)
                                            .font(.system(size: 11))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(tagColor(for: tag))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(tagColor(for: tag).opacity(0.3))
                                    .foregroundColor(tagColor(for: tag))
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(tagColor(for: tag).opacity(0.5), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
   
    /// Section for tag selection and creation
    private var tagSection: some View {
        SectionCard(title: "Add Tags") {
            VStack(alignment: .leading, spacing: 16) {
                // Combined tags section
                if !orderedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // Horizontal scrollable tag grid
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: [
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8),
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8),
                                GridItem(.adaptive(minimum: 28, maximum: 32), spacing: 8)
                            ], spacing: 8) {
                                ForEach(newTagText.isEmpty ? orderedTags : filteredTags, id: \.self) { tag in
                                    tagButton(tag)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(height: 100)
                    }
                }
                
                // Custom tag creation - moved below the tag list
                HStack {
                    TextField("Search or add custom tag...", text: $newTagText)
                        .focused($tagTextFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        .onChange(of: newTagText) { _, newValue in
                            // Filter tags when typing
                            updateFilteredTags()
                        }
                        .onSubmit {
                            addCustomTag()
                            hideKeyboard()
                        }
                   
                    Button(action: {
                        addCustomTag()
                        hideKeyboard()
                    }) {
                        Text("Add")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(newTagText.isEmpty ? Color.secondary : Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(newTagText.isEmpty)
                }
            }
        }
    }
   
    /// Tag button used throughout the interface
    private func tagButton(_ tag: String) -> some View {
        Button(action: {
            toggleTag(tag)
            hideKeyboard()
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
   
    /// Buttons for submitting or canceling the form
    private var buttonSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                clearForm()
                hideKeyboard()
            }) {
                Text("Clear")
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
           
            Button(action: {
                submitContact()
                hideKeyboard()
            }) {
                Text("Submit")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(contactText.isEmpty ? 0.5 : 1))
                    .clipShape(Capsule())
            }
            .disabled(contactText.isEmpty)
        }
    }
   
    // MARK: - Methods
    
    /// Removes a tag from the selected tags array
    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0 == tag }
        print("Removed tag: \(tag)")
    }
    
    /// Toggle a tag selection
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            removeTag(tag)
            print("Removed tag: \(tag)")
        } else {
            selectedTags.append(tag)
            print("Added tag: \(tag)")
        }
    }
   
    /// Clears the form fields
    private func clearForm() {
        contactText = ""
        selectedTags = []
        newTagText = ""
        errorMessage = nil
        successMessage = nil
        createdUser = nil
        updateFilteredTags()
    }
   
    /// Submits the contact information to the API
    private func submitContact() {
        guard !contactText.isEmpty else { return }
       
        isSubmitting = true
        errorMessage = nil
       
        // Auto-capitalize the contact text
        let capitalizedText = capitalizeContactText(contactText)
        
        // Filter out any empty tags and capitalize the rest
        let finalTags = selectedTags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { capitalizeTag($0) }
        
        print("Submitting contact with text length: \(capitalizedText.count) characters")
        print("Tags to submit: \(finalTags.isEmpty ? "none" : "\(finalTags)")")
        print("Tag count: \(finalTags.count)")
       
        // Create contact with all tags in one step (API now handles multiple tags)
        coordinator.networkManager.createContact(fromText: capitalizedText, tags: finalTags) { result in
            self.isSubmitting = false
           
            switch result {
            case .success(let userId):
                print("Contact created with ID: \(userId)")
                
                // Clear the form
                self.clearForm()
                
                // Navigate to the edit view for the newly created contact
                self.coordinator.networkManager.fetchUser(withId: userId) { userResult in
                    switch userResult {
                    case .success(let user):
                        // Navigate to the contact view in edit mode
                        DispatchQueue.main.async {
                            self.coordinator.showContactInEditMode(user)
                        }
                    case .failure(let error):
                        self.errorMessage = "Contact created but couldn't load details: \(error.localizedDescription)"
                    }
                }
                
            case .failure(let error):
                self.errorMessage = "Failed to create contact: \(error.localizedDescription)"
            }
        }
    }
   
    /// Adds a custom tag based on the newTagText value
    private func addCustomTag() {
        let trimmedText = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Capitalize the tag before adding
        let capitalizedTag = capitalizeTag(trimmedText)
        
        // Make sure the tag isn't already in the list
        if !selectedTags.contains(capitalizedTag) {
            selectedTags.append(capitalizedTag)
            print("Added custom tag: \(capitalizedTag)")
        } else {
            print("Tag already exists: \(capitalizedTag)")
        }
        
        // Reset search field and update filtering
        newTagText = ""
        updateFilteredTags()
    }
    
    /// Helper to explicitly hide the keyboard
    private func hideKeyboard() {
        contactTextFieldFocused = false
        tagTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Fetch user's recent tags
    private func fetchRecentTags() {
        guard coordinator.networkManager.userId != nil else { return }
        
        // First, directly fetch recent tags from NetworkManager
        coordinator.networkManager.fetchRecentTags()
        
        // After a short delay, get the tags from the published property
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recentTags = Array(self.coordinator.networkManager.recentTags.prefix(3))
            print("Loaded \(self.recentTags.count) recent tags from NetworkManager")
            
            // If no recent tags were loaded, try fetching with the completion handler as fallback
            if self.recentTags.isEmpty {
                self.fetchRecentTagsWithCompletion()
            } else {
                // Update the ordered tags when recent tags are loaded
                self.updateOrderedTags()
            }
        }
    }
    
    /// Fallback method to fetch recent tags using the completion handler
    private func fetchRecentTagsWithCompletion() {
        coordinator.networkManager.fetchUserRecentTags { result in
            switch result {
            case .success(let tags):
                DispatchQueue.main.async {
                    self.recentTags = Array(tags.prefix(3))
                    print("Loaded \(self.recentTags.count) recent tags via completion handler")
                    self.updateOrderedTags()
                }
            case .failure(let error):
                print("Failed to load recent tags: \(error.localizedDescription)")
            }
        }
    }
    
    /// Load all tags from connections
    private func loadAllTags() {
        // Ensure connections are loaded
        guard let userId = coordinator.networkManager.userId else { return }
        
        coordinator.networkManager.fetchConnections(forUserId: userId) 
        
        // Extract and sort tags by frequency
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let tagCounts = self.countTagsFromConnections()
            let rankedTags = tagCounts.sorted { $0.value > $1.value }.map { $0.key }
            
            // Update the ordered tags with the ranked tags
            self.filteredTags = rankedTags
            self.updateOrderedTags()
            print("Loaded \(rankedTags.count) ranked tags")
        }
    }
    
    /// Update the ordered tags list with recent tags at the front
    private func updateOrderedTags() {
        // Start with recent tags
        var newOrderedTags = recentTags
        
        // Add other tags that aren't already in the list
        for tag in filteredTags {
            if !newOrderedTags.contains(tag) {
                newOrderedTags.append(tag)
            }
        }
        
        // Update the state variable
        self.orderedTags = newOrderedTags
        print("Updated ordered tags: \(newOrderedTags.count) total with \(recentTags.count) recent tags first")
    }
    
    /// Count tag frequency in connections
    private func countTagsFromConnections() -> [String: Int] {
        var tagCounts: [String: Int] = [:]
        
        for connection in coordinator.networkManager.connections {
            if let tags = connection.tags {
                for tag in tags {
                    tagCounts[tag, default: 0] += 1
                }
            }
        }
        
        return tagCounts
    }
    
    /// Update filtered tags based on search
    private func updateFilteredTags() {
        if newTagText.isEmpty {
            // Show all tags in the ordered list
            filteredTags = orderedTags
        } else {
            // Filter tags that contain the search text
            let searchText = newTagText.lowercased()
            filteredTags = orderedTags.filter { $0.lowercased().contains(searchText) }
        }
    }
    
    /// Properly capitalize tags
    private func capitalizeTag(_ tag: String) -> String {
        return tag.split(separator: " ")
            .map { String($0).capitalized }
            .joined(separator: " ")
    }
    
    /// Capitalize contact text properly
    private func capitalizeContactText(_ text: String) -> String {
        // Keep the original formatting but ensure names and proper nouns are capitalized
        // This is a simplified implementation - a more robust solution could be implemented
        // if needed to identify proper nouns, company names, etc.
        
        // Split by newlines to preserve format
        let lines = text.split(separator: "\n")
        let processedLines = lines.map { line -> String in
            // Process each line
            let lineString = String(line)
            
            // Split by commas
            let components = lineString.split(separator: ",")
            let processedComponents = components.map { component -> String in
                let trimmed = String(component).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Don't capitalize emails or URLs
                if trimmed.contains("@") || trimmed.contains("http") {
                    return trimmed
                }
                
                // Capitalize words
                let words = trimmed.split(separator: " ")
                let capitalizedWords = words.map { String($0).capitalized }
                return capitalizedWords.joined(separator: " ")
            }
            
            // Rejoin with commas
            return processedComponents.joined(separator: ", ")
        }
        
        // Rejoin with newlines
        return processedLines.joined(separator: "\n")
    }
}

// MARK: - Helper Functions

/// Color for tag based on tag name
private func tagColor(for tag: String) -> Color {
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
    let hash = abs(tag.hashValue)
    return colors[hash % colors.count]
}