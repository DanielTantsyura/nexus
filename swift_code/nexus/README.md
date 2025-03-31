# Nexus iOS Client

A modern social networking application written in SwiftUI that connects to the Nexus API.

## Features

- **User Interface**:
  - Clean, modern SwiftUI interface with consistent design
  - User search with real-time filtering 
  - Detailed user profiles with comprehensive information
  - Edit profile functionality for the current user
  - Responsive loading states with retry mechanisms
  - Standardized UI components for consistent visual language

- **Architecture**:
  - MVVM + Coordinator pattern for clean separation of concerns
  - Centralized state management via AppCoordinator
  - Error handling and recovery strategies
  - Persistent login with UserDefaults
  - Comprehensive documentation for all components

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- macOS Ventura or later

## Setup

### Backend Setup

1. Ensure the Nexus API server is running:
   ```
   cd /path/to/nexus
   python api.py
   ```

### Network Configuration

1. For simulator testing:
   - The app defaults to `http://127.0.0.1:8080` for the API
   - No changes required

2. For physical device testing:
   - Open `NetworkManager.swift`
   - Update the physical device section:
     ```swift
     #else
     // Replace with your Mac's actual IP address when testing on a physical device
     private let baseURL = "http://YOUR_MAC_IP:8080"
     #endif
     ```

### Building and Running

1. Open the Xcode project
2. Select a simulator or device 
3. Run the application (⌘+R)

## App Structure

- **App Coordination**:
  - `NexusApp.swift`: App initialization
  - `AppCoordinator.swift`: Navigation and state management

- **Views**:
  - `ContentView.swift`: Main container view with SwiftUI navigation
  - `LoginView.swift`: Authentication screen
  - `HomeView.swift`: User profile and navigation hub
  - `UserListView.swift`: Browse and search users
  - `UserListRow.swift`: Individual user row component
  - `UserDetailView.swift`: User profile and connections management
  - `EditProfileView.swift`: Update user profile information

- **Data Layer**:
  - `NetworkManager.swift`: API communication with standardized error handling
  - `Models.swift`: Data models with comprehensive documentation

- **UI Components**:
  - `UIComponents.swift`: Reusable UI components, button styles, and status views

## Code Quality

### Documentation Standards

Every component in the application follows a consistent documentation approach:

- **File Header**: Brief description of the file's purpose
- **Type Documentation**: Detailed description for all classes, structs, and enums
- **Property Documentation**: Purpose of each property
- **Method Documentation**: Purpose, parameters, and return values
- **Section Markers**: Clear organization with MARK comments

### Component Organization

Each view is organized into logical sections:

- **Properties**: State and environment objects
- **View Body**: Main view structure
- **UI Components**: Subviews and reusable components
- **Data Management**: Methods for handling data
- **Helpers**: Utility methods and computed properties

## Application Architecture

### Component Details

#### AppCoordinator

The AppCoordinator is the central navigation controller that:
- Manages application state with `activeScreen`
- Handles navigation with `navigationPath`
- Controls user authentication
- Coordinates data refresh operations

#### NetworkManager

The NetworkManager handles all API communication with standardized error handling:
- User authentication
- Profile data fetching
- User search and listing
- Connection management
- Consistent error reporting and recovery

#### Models

The `Models.swift` file contains well-documented data structures:
- **User**: Represents user profile data
- **Connection**: Represents connection data
- **Login**: Authentication data structures
- **AuthError**: Error types for authentication

#### Reusable Components

The UIComponents.swift file provides reusable UI elements:

- **Button Styles**:
  - `PrimaryButtonStyle`: Main call-to-action style
  - `SecondaryButtonStyle`: Alternative action style

- **UI Components**:
  - `UserAvatar`: Displays user avatar with initials
  - `InfoRow`: Displays labeled information
  - `SectionCard`: Card container with title and content

- **Status Views**:
  - `LoadingView`: Display during data loading
  - `ErrorView`: Display error states with retry option
  - `EmptyStateView`: Display when no data is available

### Data Flow

1. **AppCoordinator** initiates data operations through the NetworkManager
2. **NetworkManager** fetches data from API endpoints
3. Data is stored in the NetworkManager's published properties
4. Views observe these published properties and update accordingly

### Initialization Flow

1. **NexusApp** creates the AppCoordinator
2. **AppCoordinator** checks for existing login credentials
3. If logged in, the app shows HomeView, otherwise LoginView
4. After login, the app refreshes user data

### Navigation Structure

The app uses SwiftUI's NavigationStack for clean, consistent navigation:
- **Login → Home**: After successful authentication
- **Home → UserList**: Direct NavigationLink
- **Home → EditProfile**: Coordinator-managed navigation
- **UserList → UserDetail**: Tapping on a user row
- **UserDetail → Connection Management**: Built-in functionality

### Reactive Programming

- **@Published** properties in NetworkManager and AppCoordinator provide reactivity
- **@EnvironmentObject** ensures views have access to shared state
- **@State** and **@Binding** manage view-specific state

## View Features

### Home View
- Displays current user profile with comprehensive details
- Navigation to other app sections
- Auto-retry mechanism for loading profile data
- Modular subviews for better maintainability

### User List
- Browse all users in the network
- Real-time search functionality
- Pull-to-refresh for latest data
- Clear empty and error states using standard components

### Edit Profile
- Update personal and professional information
- Organized form with logical sections
- Form validation and error handling
- Immediate profile refresh after updates

### Login
- Simple authentication interface
- Error handling for failed login attempts
- Persistent login with UserDefaults

## Troubleshooting

### API Connection Issues
1. Verify the API server is running on your machine
2. Check that the IP address in `NetworkManager.swift` is correct
3. Ensure your device is on the same network as the server
4. Try refreshing data or restarting the app

### Loading Issues
1. If profile data doesn't load, use the manual refresh option
2. Check network connection and retry
3. Ensure API responses match expected formats

## License

This project is available under the MIT License. 