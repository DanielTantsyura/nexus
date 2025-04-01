import SwiftUI

/// View for creating a new contact with a free-form text entry and tag selection
struct CreateContactView: View {
    // MARK: - Properties
    
    /// App coordinator for navigation and state management
    @EnvironmentObject private var coordinator: AppCoordinator
    
    /// Text content entered by the user
    @State private var contactText = ""
    
    /// List of suggested tags
    private let suggestedTags = ["Entrepreneurship", "Investing", "Self Improvement", "Physicality"]
    
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
                // Suggested tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(suggestedTags, id: \.self) { tag in
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
                
                Divider()
                
                // Custom tag creation
                HStack {
                    TextField("New tag", text: $newTagText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    
                    Button(action: {
                        addCustomTag()
                    }) {
                        Text("Add")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(newTagText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(newTagText.isEmpty ? .gray : .white)
                            .cornerRadius(8)
                    }
                    .disabled(newTagText.isEmpty)
                }
            }
        }
    }
    
    /// Buttons for submission or form clearing
    private var buttonSection: some View {
        HStack(spacing: 15) {
            Button(action: {
                submitContact()
            }) {
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: UIScreen.main.bounds.width * 0.6)
            .disabled(contactText.isEmpty || isSubmitting)
            
            Button(action: {
                clearForm()
            }) {
                Text("Clear")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: UIScreen.main.bounds.width * 0.2)
            .disabled(isSubmitting)
        }
        .padding(.top, 10)
    }
    
    /// Creates a tag badge with delete functionality
    /// - Parameter tag: The tag text to display
    private func tagBadge(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)
            
            Button(action: {
                removeTag(tag)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.2))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
    
    // MARK: - Action Methods
    
    /// Adds a tag to the selected tags
    /// - Parameter tag: The tag to add
    private func addTag(_ tag: String) {
        if !selectedTags.contains(tag) {
            selectedTags.append(tag)
        } else {
            removeTag(tag)
        }
    }
    
    /// Adds a custom tag from user input
    private func addCustomTag() {
        let trimmedTag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !selectedTags.contains(trimmedTag) {
            selectedTags.append(trimmedTag)
            newTagText = ""
        }
    }
    
    /// Removes a tag from the selected tags
    /// - Parameter tag: The tag to remove
    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0 == tag }
    }
    
    /// Submit the contact by calling the API
    private func submitContact() {
        guard !contactText.isEmpty else {
            errorMessage = "Please enter contact information"
            return
        }
        
        // Clear any existing messages
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        
        // Call the API to create the contact
        coordinator.networkManager.createContact(contactText: contactText, tags: selectedTags) { result in
            isSubmitting = false
            
            switch result {
            case .success(let message):
                // Show success message and clear form
                withAnimation {
                    successMessage = message
                }
                clearForm()
                
            case .failure(let error):
                // Show error message
                withAnimation {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Clear form data without navigation
    private func clearForm() {
        contactText = ""
        selectedTags = []
        newTagText = ""
        isContactTextFieldFocused = true
    }
}

// MARK: - FlowLayout

/// Flow layout for tags that wraps to next line as needed
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let containerWidth = proposal.width ?? .infinity
        
        var height: CGFloat = 0
        var width: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowWidth + size.width > containerWidth {
                // Start a new row
                width = max(width, rowWidth)
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                // Add to current row
                rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }
        }
        
        // Add the last row
        height += rowHeight
        width = max(width, rowWidth)
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        
        let containerWidth = bounds.width
        
        var rowX: CGFloat = bounds.minX
        var rowY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if rowX + size.width > containerWidth + bounds.minX {
                // Start a new row
                rowX = bounds.minX
                rowY += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(at: CGPoint(x: rowX, y: rowY), proposal: .unspecified)
            
            rowHeight = max(rowHeight, size.height)
            rowX += size.width + spacing
        }
    }
}

// MARK: - Preview

#Preview {
    CreateContactView()
        .environmentObject(AppCoordinator())
} 