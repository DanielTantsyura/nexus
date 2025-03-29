# Nexus iOS Application

A native iOS client for the Nexus social networking application.

## Features

- **User Interface**
  - User list with search functionality
  - Detailed user profiles with contact information
  - Connection management with relationship types
  - Modern SwiftUI interface with proper loading states

- **Architecture**
  - MVVM + Coordinator pattern for clean separation of concerns
  - Centralized state management
  - Network abstraction layer with error handling
  - Responsive UI that adapts to data changes

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- macOS Ventura or later (for development)

## Running the Application

1. **Set up the backend**
   - Follow the instructions in the main README to set up and run the API server
   - Make sure the server is running on port 8080
   - Run `python setup.py` to reset the database if needed
   - Run `python api.py` to start the server

2. **Configure the network connection**
   - Open `NetworkManager.swift` 
   - Verify the `baseURL` settings:
     - For simulator: Uses localhost (127.0.0.1)
     - For physical device: Update with your Mac's IP address

3. **Build and run the app**
   - Open the project in Xcode
   - Select a simulator or connected device
   - Press ⌘+R or click the play button

## App Structure

- **App Entry Point**
  - `NexusApp.swift`: Main app entry point with coordinator setup

- **Views**
  - `ContentView.swift`: Main view hierarchy organized into components
    - `UserListRow`: Row item for the user list
    - `UserDetailView`: Detailed user profile display
    - `AddConnectionView`: UI for adding new connections

- **Networking**
  - `NetworkManager.swift`: API communication and data handling
  - Includes error handling and retry mechanisms

- **Models**
  - `Models/User.swift`: User model with profile information
  - `Models/Connection.swift`: Connection model for relationships  

- **Architecture**
  - `App/AppCoordinator.swift`: Coordinator for managing navigation and state

## Features in Detail

### User List
- Displays all users from the Nexus database
- Search functionality to filter users
- Pull-to-refresh to update data
- Loading states with visual indicators

### User Details
- Complete profile with contact information
- List of connections with relationship types
- Add/remove connections directly from profile
- Auto-refresh when connections change

### Connection Management
- Add connections with custom relationship types
- Remove connections with a single tap
- Reliable connection loading with retry mechanism
- Visual feedback during operations

## Troubleshooting

If you encounter connection issues:

1. **Check API Connection**
   - Ensure the API server is running
   - Test with: `curl http://localhost:8080/users`

2. **Common Issues**
   - Connection refused: Start the API with `python api.py`
   - Empty user list: Pull down to refresh or tap refresh button
   - Connection failures: Check API logs

3. **Reset Everything**
   ```bash
   cd ~/nexus
   python setup.py
   python api.py
   ```

## For Developers

To extend this application:

1. **Adding new views**
   - Follow the MVVM pattern with SwiftUI
   - Register views in the AppCoordinator navigation path

2. **Adding new API endpoints**
   - Add methods to the NetworkManager class
   - Follow the established error handling pattern

3. **Modifying the data models**
   - Update model files to match the backend schema
   - Ensure Codable and Hashable conformance for navigation 