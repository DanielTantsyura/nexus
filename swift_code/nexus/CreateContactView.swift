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
    
    /// Controls whether the keyboard is active
    @FocusState private var isContactTextFieldFocused: Bool
    
    /// Error message to display
    @State private var errorMessage: String? = nil
    
    /// Success message to display
    @State private var successMessage: String? = nil
    
    /// Whether a submit operation is in progress
    @State private var isSubmitting = false
    
    // MARK: - View Body
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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
        .navigationTitle("Create Contact")
        .onAppear {
            // Auto-focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isContactTextFieldFocused = true
            }
        }
        .disabled(isSubmitting)
        .overlay(
            Group {
                if isSubmitting {
                    LoadingView(message: "Creating contact...")
                }
            }
        )
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
        SectionCard(title: "Contact Information") {
            TextEditor(text: $contactText)
                .frame(minHeight: 150)
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .focused($isContactTextFieldFocused)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    /// View displaying selected tags with delete functionality
    private var selectedTagsView: some View {
        Group {
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Tags")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tag in
                            tagBadge(tag)
                        }
                    }
                }
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
                        
                        FlowLayout(spacing: 8) {
                            ForEach(coordinator.networkManager.recentTags, id: \.self) { tag in
                                Button(action: {
                                    addTag(tag)
                                }) {
                                    Text(tag)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedTags.contains(tag) ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedTags.contains(tag) ? .blue : .primary)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Custom tag creation
                HStack {
                    TextField("Add custom tag...", text: $newTagText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: addCustomTag) {
                        Text("Add")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(newTagText.isEmpty ? Color.gray : Color.blue)
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
            Button(action: clearForm) {
                Text("Clear")
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            
            Button(action: submitContact) {
                Text("Submit")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(contactText.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(contactText.isEmpty)
        }
    }
    
    /// Creates a tag badge with remove functionality
    private func tagBadge(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .padding(.leading, 8)
            
            Button(action: {
                removeTag(tag)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .padding(.trailing, 6)
        }
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
    
    // MARK: - Methods
    
    /// Adds a custom tag based on the newTagText value
    private func addCustomTag() {
        let trimmedText = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        addTag(trimmedText)
        newTagText = ""
    }
    
    /// Adds a tag to the selected tags array if not already present
    private func addTag(_ tag: String) {
        if !selectedTags.contains(tag) {
            selectedTags.append(tag)
        } else {
            removeTag(tag)
        }
    }
    
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
                // Wait a moment so the user sees the success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Navigate to the user detail view for the new contact
                    coordinator.networkManager.fetchUser(withId: userId) { userResult in
                        switch userResult {
                        case .success(let user):
                            clearForm()
                            coordinator.showUserDetail(user: user)
                        case .failure:
                            // If we can't fetch the user, just go back
                            coordinator.backFromCreateContact()
                        }
                    }
                }
            case .failure(let error):
                errorMessage = "Failed to create contact: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - FlowLayout

/// A layout that arranges elements in rows, wrapping to a new row when needed
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 10) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // If this element doesn't fit on the current row, start a new row
            if rowWidth + subviewSize.width > containerWidth && rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = subviewSize.width
                rowHeight = subviewSize.height
            } else {
                // Add to the current row
                rowWidth += subviewSize.width + spacing
                rowHeight = max(rowHeight, subviewSize.height)
            }
        }
        
        // Add the height of the last row
        totalHeight += rowHeight
        
        return CGSize(width: containerWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var rowMinY: CGFloat = bounds.minY
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            
            // Check if this element needs to go on a new row
            if rowWidth + subviewSize.width > bounds.width && rowWidth > 0 {
                rowMinY += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            
            // Place the element
            let xPos = bounds.minX + rowWidth
            let yPos = rowMinY + (rowHeight - subviewSize.height) / 2
            
            subview.place(at: CGPoint(x: xPos, y: yPos), proposal: .unspecified)
            
            // Update tracking variables
            rowWidth += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        CreateContactView()
            .environmentObject(AppCoordinator())
    }
} 
} 