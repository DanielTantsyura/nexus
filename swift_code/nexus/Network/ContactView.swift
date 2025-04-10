import SwiftUI
import Combine

struct ContactView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    
    // MARK: - State
    
    let initialUser: User
    
    // This is the @State copy that SwiftUI watches
    @State private var user: User
    
    @State private var isEditing = false
    @State private var relationship: Connection?
    @State private var isLoadingRelationship = true
    @State private var relationshipError: String?
    
    /// The main toggle for forcing a refresh of the entire ContactView
    @State private var refreshTrigger = false
    
    // For subscribing to refresh signals
    @State private var refreshCancellable: AnyCancellable?
    
    // Editing state variables...
    @State private var editFirstName = ""
    @State private var editLastName = ""
    @State private var editJobTitle = ""
    @State private var editCompany = ""
    @State private var editUniversity = ""
    @State private var editUniMajor = ""
    @State private var editLocation = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editGender = ""
    @State private var editEthnicity = ""
    @State private var editInterests = ""
    @State private var editHighSchool = ""
    @State private var editNotes = ""
    @State private var editLinkedinUrl = ""
    @State private var editBirthday = ""
    
    // Tags
    @State private var editTags: [String] = []
    @State private var newTagText = ""
    @FocusState private var tagTextFieldFocused: Bool
    
    // Confirmation dialog
    @State private var showDeleteConfirmation = false
    
    // This init sets up your local copy of `user`
    init(user: User) {
        self.initialUser = user
        self._user = State(initialValue: user)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                userInfoSection
                if let relationship = relationship, let notes = relationship.notes {
                    notesSection(notes: notes)
                }
                combinedInfoSection
            }
            .padding()
        }
        .id("contact-view-\(refreshTrigger)")  // This forces a fresh load of the entire body when toggled
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button(action: { saveChanges() }) {
                        Image(systemName: "checkmark")
                    }
                } else {
                    Button(action: { startEditing() }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button(action: { cancelEditing() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete Contact",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteContact()
            }
            Button("Cancel", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("Are you sure you want to delete this contact? This action cannot be undone.")
        }
        .onAppear {
            coordinator.activeScreen = .contact
            loadRelationship()
            updateLastViewed()
            
            // Check if we should start in edit mode
            if UserDefaults.standard.bool(forKey: "StartContactInEditMode") {
                let editContactId = UserDefaults.standard.integer(forKey: "EditContactId")
                if editContactId == user.id {
                    // Clear the flags so it only happens once
                    UserDefaults.standard.set(false, forKey: "StartContactInEditMode")
                    UserDefaults.standard.removeObject(forKey: "EditContactId")
                    
                    print("Starting edit mode for newly created contact: \(user.id)")
                    
                    // Start editing after a short delay to ensure view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isEditing = true
                        startEditing()
                    }
                }
            }
            
            // Subscribe to refresh signals so we can toggle refreshTrigger
            refreshCancellable = coordinator.networkManager.$refreshSignal
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    let refreshType = coordinator.networkManager.lastRefreshType
                    // Only refresh if it's relevant for connections or contact changes
                    if refreshType == .connections {
                        // Relationship data might have changed or re-fetched
                        self.loadRelationship() 
                        refreshTrigger.toggle()
                    }
                }
                
            // Listen for cancel editing notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CancelContactEditing"),
                object: nil,
                queue: .main
            ) { _ in
                if self.isEditing {
                    self.isEditing = false
                }
            }
        }
        .onDisappear {
            // Clean up the subscription
            refreshCancellable?.cancel()
            
            // Cancel editing if active when navigating away
            if isEditing {
                isEditing = false
            }
            
            // Remove the notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CancelContactEditing"), object: nil)
        }
    }
    
    // MARK: - Relationship Loading
    
    private func loadRelationship() {
        guard let currentUserId = coordinator.networkManager.userId else { return }
        guard currentUserId != user.id else { return } // Skip if looking at ourselves
        
        // If we don't already have a relationship or if the manager doesn't have them fetched
        if relationship == nil || coordinator.networkManager.connections.isEmpty {
            isLoadingRelationship = true
            coordinator.networkManager.fetchConnections(forUserId: currentUserId)
            // We'll rely on the refresh signal that fetchConnections emits
        }
        
        // Try to find the connection in the manager's memory
        let found = coordinator.networkManager.connections.first { $0.id == self.user.id }
        self.relationship = found
        self.isLoadingRelationship = false
    }
    
    private func updateLastViewed() {
        guard let currentUserId = coordinator.networkManager.userId else { return }
        guard currentUserId != user.id else { return }
        
        coordinator.networkManager.updateConnectionTimestamp(contactId: user.id) { _ in
            // Not super critical if it fails, just ignore
        }
    }
    
    // MARK: - Subviews
    
    private var userInfoSection: some View {
        SectionCard(title: "") {
            VStack(alignment: .leading, spacing: 16) {
                userHeaderView
                if !isEditing, let relationship = relationship, let tags = relationship.tags, !tags.isEmpty {
                    // Read-only tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(tagColor(for: tag).opacity(0.2))
                                    .foregroundColor(tagColor(for: tag))
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else if isEditing {
                    tagManagementSection
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture { startEditing() }
    }
    
    private var userHeaderView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    HStack {
                        TextField("First Name", text: $editFirstName)
                            .font(.title2).fontWeight(.bold)
                        TextField("Last Name", text: $editLastName)
                            .font(.title2).fontWeight(.bold)
                    }
                    HStack(spacing: 8) {
                        TextField("Job Title", text: $editJobTitle)
                            .font(.subheadline).fontWeight(.semibold)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.6))
                            TextField("Company", text: $editCompany)
                                .font(.subheadline)
                        }
                    }
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "building.columns.fill")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.7))
                            TextField("University", text: $editUniversity)
                                .font(.subheadline)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            TextField("Location", text: $editLocation)
                                .font(.subheadline)
                        }
                    }
                } else {
                    Text(user.fullName)
                        .font(.largeTitle).fontWeight(.bold)
                    
                    if let jobTitle = user.jobTitle, let company = user.currentCompany {
                        HStack {
                            Text(jobTitle)
                                .font(.subheadline).fontWeight(.bold)
                                .foregroundColor(.gray)
                            Image(systemName: "building.2.fill")
                                .foregroundColor(Color.blue.opacity(0.5))
                            Text(company)
                                .foregroundColor(.gray)
                        }
                    } else if let jobTitle = user.jobTitle {
                        Text(jobTitle)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundColor(.gray)
                    } else if let company = user.currentCompany {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(Color.blue.opacity(0.5))
                            Text(company)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        if let university = user.university {
                            Image(systemName: "graduationcap.fill")
                                .foregroundColor(Color.blue.opacity(0.5))
                            Text(university)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        if let location = user.location {
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            Spacer()
            UserAvatar(user: user, size: 80)
        }
        .padding(.bottom, 8)
    }
    
    private func notesSection(notes: String) -> some View {
        SectionCard(title: "Notes") {
            if isEditing {
                VStack(alignment: .leading) {
                    Text("Notes about this contact")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                    
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.vertical, 8)
            } else {
                Text(notes)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    private var combinedInfoSection: some View {
        SectionCard(title: "Contact Information") {
            VStack(alignment: .leading, spacing: 12) {
                if let relationship = relationship, let description = relationship.relationshipDescription {
                    InfoRow(icon: "person.2.fill", title: "Relationship Description", value: description)
                    Divider().padding(.vertical, 4)
                }
                
                if isEditing {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Birthday")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("MM/DD/YYYY", text: $editBirthday)
                        }
                    }
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Email", text: $editEmail)
                        }
                    }
                    HStack {
                        Image(systemName: "phone.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Phone")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("Phone", text: $editPhone)
                        }
                    }
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LinkedIn")
                                .font(.caption)
                                .foregroundColor(.gray)
                            TextField("LinkedIn URL", text: $editLinkedinUrl)
                        }
                    }
                    
                    // Delete contact
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Delete Contact")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.red.opacity(0.6), lineWidth: 1)
                        )
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                } else {
                    if let birthday = user.birthday {
                        InfoRow(icon: "calendar", title: "Birthday", value: birthday)
                            .padding(.vertical, 4)
                    }
                    if let email = user.email {
                        // Tappable row that tries to open mail app
                        HStack {
                            InfoRow(icon: "envelope.fill", title: "Email", value: email)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if let phone = user.phoneNumber {
                        // Tappable row that tries to open phone
                        HStack {
                            InfoRow(icon: "phone.fill", title: "Phone", value: phone)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "tel:\(phone.filter { !$0.isWhitespace })") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if let linkedin = user.linkedinUrl, !linkedin.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("LinkedIn")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: linkedin), UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button(action: {
                        startEditing()
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                            Text("Edit Contact")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 10)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Tag Management
    
    private var tagManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
                .padding(.vertical, 4)
            
            // Display selected tags
            if !editTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(editTags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.system(size: 12))
                                Button(action: {
                                    removeTag(tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(tagColor(for: tag))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(tagColor(for: tag).opacity(0.3))
                            .foregroundColor(tagColor(for: tag))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(tagColor(for: tag).opacity(0.5), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Recent tags
            if !coordinator.networkManager.recentTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(coordinator.networkManager.recentTags, id: \.self) { tag in
                                Button(action: {
                                    toggleTag(tag)
                                }) {
                                    Text(tag)
                                        .font(.system(size: 11))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(editTags.contains(tag)
                                            ? tagColor(for: tag).opacity(0.3)
                                            : tagColor(for: tag).opacity(0.1))
                                        .foregroundColor(editTags.contains(tag)
                                            ? tagColor(for: tag)
                                            : tagColor(for: tag).opacity(0.8))
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(tagColor(for: tag).opacity(editTags.contains(tag) ? 0.5 : 0.2), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            
            // Add new tag
            HStack {
                TextField("Add custom tag...", text: $newTagText)
                    .focused($tagTextFieldFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(8)
                    .onSubmit {
                        addCustomTag()
                    }
                
                Button(action: {
                    addCustomTag()
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
            .padding(.top, 8)
        }
        .padding(.top, 4)
    }
    
    private func removeTag(_ tag: String) {
        editTags.removeAll { $0 == tag }
    }
    
    private func toggleTag(_ tag: String) {
        if editTags.contains(tag) {
            removeTag(tag)
        } else {
            editTags.append(tag)
        }
    }
    
    private func addCustomTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !editTags.contains(trimmed) {
            editTags.append(trimmed)
        }
        newTagText = ""
        tagTextFieldFocused = false
    }
    
    // MARK: - Edit Mode
    
    private func startEditing() {
        editFirstName = user.firstName ?? ""
        editLastName = user.lastName ?? ""
        editJobTitle = user.jobTitle ?? ""
        editCompany = user.currentCompany ?? ""
        editUniversity = user.university ?? ""
        editUniMajor = user.uniMajor ?? ""
        editLocation = user.location ?? ""
        editEmail = user.email ?? ""
        editPhone = user.phoneNumber ?? ""
        editGender = user.gender ?? ""
        editEthnicity = user.ethnicity ?? ""
        editInterests = user.fieldOfInterest ?? ""
        editHighSchool = user.highSchool ?? ""
        editNotes = relationship?.notes ?? ""
        editLinkedinUrl = user.linkedinUrl ?? ""
        editBirthday = user.birthday ?? ""
        editTags = relationship?.tags ?? []
        
        isEditing = true
    }
    
    private func saveChanges() {
        // Prepare the user data
        var userData: [String: Any] = [:]
        userData["first_name"] = editFirstName
        userData["last_name"] = editLastName
        userData["job_title"] = editJobTitle
        userData["current_company"] = editCompany
        userData["university"] = editUniversity
        userData["uni_major"] = editUniMajor
        userData["location"] = editLocation
        userData["email"] = editEmail
        userData["phone_number"] = editPhone
        userData["gender"] = editGender
        userData["ethnicity"] = editEthnicity
        userData["field_of_interest"] = editInterests
        userData["high_school"] = editHighSchool
        userData["linkedin_url"] = editLinkedinUrl
        userData["birthday"] = editBirthday
        
        let currentRelationship = relationship
        
        coordinator.networkManager.updateUser(userId: user.id, userData: userData) { result in
            switch result {
            case .success(true):
                // Refresh the updated user info
                coordinator.networkManager.fetchUser(withId: self.user.id) { fetchResult in
                    DispatchQueue.main.async {
                        if case .success(let updatedUser) = fetchResult {
                            self.user = updatedUser
                        }
                        // Turn off editing
                        self.isEditing = false
                        
                        // Update relationship (notes + tags) if we have it
                        if let relationship = currentRelationship {
                            coordinator.networkManager.updateConnection(
                                contactId: self.user.id,
                                description: relationship.relationshipDescription,
                                notes: self.editNotes,
                                tags: self.editTags
                            ) { updateResult in
                                if case .success(true) = updateResult {
                                    // Force a refresh of connections from the network manager
                                    coordinator.networkManager.fetchConnections(forUserId: coordinator.networkManager.userId ?? 0)
                                }
                            }
                        }
                    }
                }
            case .success(false), .failure(_):
                self.isEditing = false
            }
        }
    }
    
    private func cancelEditing() {
        isEditing = false
    }
    
    private func deleteContact() {
        coordinator.networkManager.deleteContact(contactId: user.id) { result in
            switch result {
            case .success(true):
                coordinator.navigateBack()
                coordinator.networkManager.signalRefresh(type: .connections)
            default:
                print("Failed to delete contact")
            }
        }
    }
    
    // MARK: - Misc
    
    private func tagColor(for tag: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red]
        let hash = abs(tag.hashValue)
        return colors[hash % colors.count]
    }
}