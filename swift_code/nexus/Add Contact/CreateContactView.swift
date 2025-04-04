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
   
    /// User created after submitting the form
    @State private var createdUser: User? = nil
   
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
                        coordinator.backFromCreateContact()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                            .font(.system(size: 18))
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
               
                // Success state - show a success message and redirect options
                if let user = createdUser {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Contact Created Successfully!")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You've successfully added \(user.firstName ?? "") to your network!")
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                coordinator.showContact(user)
                            }) {
                                Text("View Contact")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            
                            Button(action: {
                                clearForm()
                            }) {
                                Text("Add Another")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
               
                Spacer()
            }
            .padding()
        }
        .navigationBarHidden(true)
        .onAppear {
            // Auto-focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isContactTextFieldFocused = true
            }
            
            // Fetch recent tags when the view appears
            coordinator.networkManager.fetchRecentTags()
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
        SectionCard(title: "") {
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
                   
                    // Use fixed height container for proper layout
                    VStack(alignment: .leading) {
                        ForEach(selectedTags, id: \.self) { tag in
                            TagBadge(text: tag, showRemoveButton: true) {
                                removeTag(tag)
                            }
                            .padding(.bottom, 4)
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
                                GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
                            ],
                            spacing: 8
                        ) {
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
                                        .frame(maxWidth: .infinity)
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
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(contactText.isEmpty ? 0.5 : 1))
                    .clipShape(Capsule())
            }
            .disabled(contactText.isEmpty)
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
                // Wait a moment so the user sees the success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Navigate to the user detail view for the new contact
                    coordinator.networkManager.fetchUser(withId: userId) { userResult in
                        switch userResult {
                        case .success(let user):
                            createdUser = user
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
}

// MARK: - Preview

#Preview {
    NavigationView {
        CreateContactView()
            .environmentObject(AppCoordinator())
    }
}