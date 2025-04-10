# Nexus iOS Client

The iOS client for the Nexus networking application, a platform for managing professional connections and contacts.

## Project Structure

- **Nexus/**: Main application code
  - **Login/**: Authentication-related views
    - `LoginView.swift`: Login interface
    - `CreateAccountView.swift`: Account creation interface
  - **Network/**: Network management views
    - `NetworkView.swift`: Main connections view with search functionality
    - `ContactView.swift`: Detailed view for contacts
    - `UserListRow.swift`: Reusable component for user listings
  - **Profile/**: User profile
    - `ProfileView.swift`: User profile management
  - **Add Contact/**: Contact creation
    - `CreateContactView.swift`: Interface for adding new contacts
  - `NetworkManager.swift`: API communication service
  - `Models.swift`: Data models
  - `KeychainHelper.swift`: Secure storage for credentials

## Architecture

The application uses SwiftUI for its user interface and follows a coordinator-based navigation pattern. The NetworkManager class provides a centralized service for API communication, handling authentication, data fetching, and error handling.

Key architectural points:
- **MVVM pattern**: Views are kept simple with separate model and view logic
- **Publisher-based networking**: Combine framework for asynchronous operations
- **Centralized API communication**: Single class manages all network requests
- **Secure credential storage**: Keychain integration for sensitive data

## Getting Started

1. **Prerequisites**:
   - Xcode 14.0 or later
   - macOS Ventura or later
   - Nexus API running (local or remote)

2. **Environment Setup**:
   - By default, the app connects to the remote Nexus API
   - To use a local API, set the `USE_LOCAL_API` environment variable to `true` in the run scheme

3. **Running the App**:
   - Open `nexus.xcodeproj` in Xcode
   - Select a simulator or connected device
   - Press the Play button (⌘+R)

## API Integration

The application interacts with the Nexus API through the NetworkManager class. The base URL automatically adjusts based on:
- Environment variable settings for local development
- Production configuration for deployed instances

Key integrations include:
- User profile synchronization
- Connection management with tags and notes
- Natural language contact creation
- Automatic relationship description generation

## Authentication Flow

1. User logs in with username/password or creates a new account
2. Credentials are securely stored in the Keychain
3. Session is automatically restored on app launch when available
4. Token expiration is handled gracefully with automatic logout

## Features

- **User Authentication**: Login, registration, session management
- **Profile Management**: View and edit user profiles
- **Connection Management**: Add, view, filter, and search connections
- **Contact Creation**: Add new contacts to your network with natural language
- **Real-time Search**: Filter connections as you type
- **Tag-based Organization**: Categorize and filter connections by tags
- **Intelligent Relationship Descriptions**: Contextual relationship labels based on user profiles and tags

## Troubleshooting

- **Connection Issues**: Verify API accessibility and network connectivity
- **Authentication Failures**: Check credentials and API status
- **Data Not Loading**: Ensure the user is properly authenticated
- **Search Not Working**: Verify the search endpoint is operational

## Performance Considerations

- The app uses efficient in-memory filtering for real-time search
- Network requests implement retry logic with exponential backoff
- Images are cached to improve scrolling performance
- API responses are parsed on background threads

## Security Notes

- Credentials are stored securely in the Keychain
- Network requests use HTTPS in production
- Sensitive operations validate user authentication
- Session tokens are managed securely 