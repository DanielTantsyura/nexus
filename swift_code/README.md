# Nexus iOS Client

The iOS client for the Nexus networking application.

## Project Structure

- **Models/**: Data models used throughout the app
  - `User.swift`: Model for user data
  - `Connection.swift`: Model for user connections

- **App/**: Application core
  - `AppCoordinator.swift`: Central coordinator for app state and navigation
  - `NexusApp.swift`: SwiftUI application entry point

- **Views/**: User interface components
  - `ContentView.swift`: Main user interface

- **NetworkManager.swift**: Handles API communication

## Project Setup

1. **Prerequisites**:
   - Xcode 13.0 or later
   - macOS Monterey or later
   - Running Nexus API (on port 8080)

2. **Opening the Project**:
   - Open `nexus.xcodeproj` in Xcode
   - Wait for Xcode to index the project

3. **Running the App**:
   - Select a simulator or connected device
   - Press the Play button (⌘+R)

## Testing on a Physical Device

When testing on a physical device, you'll need to update the device IP address in `NetworkManager.swift`:

```swift
#if targetEnvironment(simulator)
private let baseURL = "http://127.0.0.1:8080"  // For simulator
#else
private let baseURL = "http://YOUR.IP.ADDRESS:8080"  // For physical device
#endif
```

Replace `YOUR.IP.ADDRESS` with your Mac's IP address.

## Troubleshooting

If you encounter connection issues:

1. Make sure the API is running on port 8080
2. Check that App Transport Security settings allow unencrypted HTTP connections
3. If running on a physical device, ensure it's on the same network as your Mac
4. Use the verbose logging in the app to diagnose connection issues

## Common Issues

- **"Cannot connect to API"**: Check that API is running and accessible
- **"No data found"**: Verify the database has been set up with sample data
- **"JSON parsing error"**: The API response format may have changed, check model compatibility 