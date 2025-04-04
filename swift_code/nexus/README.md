# Nexus iOS Client

A personal network management application built with SwiftUI that connects to the Nexus API for managing contacts and relationships.

## App Architecture

The Nexus iOS client follows a structured architecture with these key components:

- **Central Coordinator**: `AppCoordinator.swift` manages application state and navigation flow
- **Network Layer**: `NetworkManager.swift` handles all API communication
- **Data Models**: `Models.swift` defines the core data structures used throughout the app
- **Tab-Based Navigation**: `MainTabView.swift` organizes the app into Network and Profile sections

## Key Features

- **User Authentication**: Login system with persistent session storage
- **Contact Management**: View, search, and manage contact information
- **Relationship Tracking**: Connect with users and maintain relationship details
- **Natural Language Contact Creation**: Add contacts by describing them in free-form text
- **Profile Management**: Edit and view comprehensive profile information

## Primary View Controllers

- **MainTabView**: Tab-based navigation controller with custom styling
- **UserListView**: Browse and search through available contacts
- **ContactView**: View comprehensive contact information and manage connections
- **CreateContactView**: Add new contacts using natural language processing
- **ProfileView**: View and manage the current user's profile
- **EditProfileView**: Update profile information with form-based editing

## Network Operations

The `NetworkManager` class handles all API communication:

- **User Operations**: Fetch, search, create, and update user profiles
- **Connection Management**: Add, update, and retrieve connections
- **Authentication**: Login, session persistence, and session validation
- **Error Handling**: Standardized error processing with retry capabilities

## Data Models

The app uses these primary data structures:

- **User**: Represents a person's profile with comprehensive details
- **Connection**: Represents a relationship between users with custom notes and tags
- **Login/LoginResponse**: Authentication-related data structures

## Usage Flow

1. **Authentication**:
   - App starts with login screen 
   - After successful login, user credentials are stored for future sessions

2. **Main Navigation**:
   - Network tab shows user's connections and search functionality
   - Profile tab displays current user's information
   - Add New button in the center initiates contact creation

3. **Adding Contacts**:
   - Free-form text entry describing the contact
   - System processes text using NLP to extract structured data
   - Relationships are automatically created with the new contact

4. **Managing Relationships**:
   - View connection details from the user detail screen
   - Add notes and tags to categorize and remember details
   - Update relationship information as needed

## UI Components

The app uses several reusable components defined in `UIComponents.swift`:

- **UserAvatar**: Displays user profile image or initials
- **SectionCard**: Card-style container for information sections
- **InfoRow**: Standard format for displaying labeled information

## Setup Instructions

### For Simulator Testing

The app automatically configures itself to use `http://127.0.0.1:8080` as the API endpoint when running in the simulator.

### For Physical Device Testing

When running on a physical device, you need to update the base URL in `NetworkManager.swift`:

```swift
#if targetEnvironment(simulator)
return "http://127.0.0.1:8080"  // IPv4 localhost for simulator
#else
return "http://YOUR.MAC.IP.ADDRESS:8080"  // Replace with your Mac's IP address
#endif
```

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- Nexus API running on localhost or accessible network address

## Troubleshooting

### Common Issues

1. **"Cannot connect to API"**: 
   - Ensure the Flask API is running
   - Check that port 8080 is not blocked
   - For physical devices, verify network connectivity

2. **"Data doesn't load"**:
   - Pull to refresh in list views
   - Check API server logs for errors
   - Verify database contains sample data

3. **"Profile not updating"**:
   - Force refresh using the refresh button
   - Check API responses for errors
   - Ensure data matches expected format

## License

This project is available under the MIT License. 