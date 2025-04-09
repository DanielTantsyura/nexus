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
                // App header with X button
                AppHeader(
                    firstName: coordinator.networkManager.currentUser?.firstName,
                    subtitle: "Your personal network tracker"
                ) {
                    Button(action: {
                        clearForm()
                        hideKeyboard()
                        coordinator.backFromCreateContact()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                            .font(.system(size: 24))
                            .frame(height: 50)
                    }
                }
                .padding(.bottom, 10)
                
                // Title
                Text("Create Contact")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                // Error message
                if let errorMessage = errorMessage {
                    errorBanner(message: errorMessage)
                }
               
                // Success message
                if let successMessage = successMessage {
                    successBanner(message: successMessage)
                }
               
                // Contact text entry area
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
            // Auto-focus the contact text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                contactTextFieldFocused = true
            }
            
            // Fetch recent tags when the view appears
            coordinator.networkManager.fetchRecentTags()
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
        SectionCard(title: "") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $contactText)
                    .frame(minHeight: 150)
                    .padding(4)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .focused($contactTextFieldFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                if contactText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("First Name Last Name 123-456-7890 SpaceX Product Manager Hiking Pickleball Met at John's 24th Birthday Lives in Austin TX")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
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
                // Recent tags
                if !coordinator.networkManager.recentTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                       
                        // Use a LazyVGrid for tag layout instead of FlowLayout
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(sortedTags, id: \.self) { tag in
                                Button(action: {
                                    addTag(tag)
                                    hideKeyboard()
                                }) {
                                    Text(tag)
                                        .font(.system(size: 11))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: .infinity)
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
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
               
                // Custom tag creation
                HStack {
                    TextField("Add custom tag...", text: $newTagText)
                        .focused($tagTextFieldFocused)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
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
    }
   
    /// Clears the form fields
    private func clearForm() {
        contactText = ""
        selectedTags = []
        newTagText = ""
        errorMessage = nil
        successMessage = nil
        createdUser = nil
    }
   
    /// Submits the contact information to the API
    private func submitContact() {
        guard !contactText.isEmpty else { return }
       
        isSubmitting = true
        errorMessage = nil
       
        coordinator.networkManager.createContact(fromText: contactText, tags: selectedTags) { result in
            isSubmitting = false
           
            switch result {
            case .success(let userId):
                successMessage = "Contact created successfully!"
                // Automatically hide success message after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        successMessage = nil
                    }
                }
                // Clear the form after successful creation
                clearForm()
                
            case .failure(let error):
                errorMessage = "Failed to create contact: \(error.localizedDescription)"
            }
        }
    }
   
    /// Adds a tag to the selected tags array if not already present
    private func addTag(_ tag: String) {
        if !selectedTags.contains(tag) {
            selectedTags.append(tag)
        } else {
            removeTag(tag)
        }
    }
   
    /// Adds a custom tag based on the newTagText value
    private func addCustomTag() {
        let trimmedText = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
       
        addTag(trimmedText)
        newTagText = ""
    }
    
    /// Helper to explicitly hide the keyboard
    private func hideKeyboard() {
        contactTextFieldFocused = false
        tagTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Helper Functions

/// Color for tag based on tag name
private func tagColor(for tag: String) -> Color {
    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
    let hash = abs(tag.hashValue)
    return colors[hash % colors.count]
}