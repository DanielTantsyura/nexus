# Nexus iOS Client

A modern social networking application written in SwiftUI that connects to the Nexus API.

## Features

- **User Interface**:
  - Modern, intuitive SwiftUI interface with consistent design language
  - User search functionality with filtering options
  - Detailed user profiles with personal and professional information
  - Connection management with relationship visualization
  - Authentication system with login support

- **Architecture**:
  - MVVM + Coordinator pattern for clean separation of concerns
  - Reactive programming with Combine
  - Centralized state management
  - Clear error handling and loading states

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- macOS Ventura or later

## Setup

### Backend Setup

1. Ensure the Nexus API server is running. See the main project README for details.

### Network Configuration

1. For simulator testing:
   - The app defaults to `http://127.0.0.1:8080` for the API
   - No changes required

2. For physical device testing:
   - Open `NetworkManager.swift`
   - Update `baseURL` to your Mac's IP address: 
     ```swift
     static let baseURL = "http://YOUR_MAC_IP:8080"
     ```

### Building and Running

1. Open the Xcode project:
   ```
   open swift_code/nexus.xcodeproj
   ```

2. Select a simulator or device as your run target

3. Run the application (⌘+R)

## App Structure

- **Main Entry Point**:
  - `NexusApp.swift`: App initialization and dependency injection

- **Views**:
  - `ContentView.swift`: Root view and navigation container
  - `UserListView.swift`: Display and search user list
  - `UserDetailView.swift`: Detailed user profile view with connection options
  - `AddConnectionView.swift`: Interface for creating new connections
  - `LoginView.swift`: Authentication interface

- **Networking**:
  - `NetworkManager.swift`: API communication with the Nexus backend

- **Models**:
  - `Models/User.swift`: User data model with Codable conformance
  - `Models/Connection.swift`: Connection data model with relationship types
  - `Models/Login.swift`: Login credential model

## Features in Detail

### User List
- View all users in the system
- Pull-to-refresh functionality
- Search by name, university, location, or interests
- Each user card displays essential profile information

### User Details
- View comprehensive user profile information
- See existing connections for the user
- Manage connections with the user
- View professional and academic information

### Connection Management
- Create bidirectional connections with relationship type
- View connection history
- Remove connections

### Authentication
- Login with username and password
- Access user-specific data
- Secure credential storage

## Troubleshooting

### API Connection Issues
1. Verify the API server is running on your machine
2. Check that the IP address in `NetworkManager.swift` is correct
3. Ensure your device is on the same network as the server

### Build Errors
1. Update to the latest Xcode version
2. Clean the build folder (Shift+⌘+K) and rebuild
3. Check Swift Package dependencies are correctly resolved

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is available under the MIT License. 