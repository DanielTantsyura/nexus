# Nexus Application

A modern social networking application featuring a Flask backend API and a native iOS client built with SwiftUI. Nexus enables users to create profiles, search for connections, and manage their professional network.

## Overview

Nexus is a modern social networking platform with a Flask-based backend API and a native iOS client. The project implements user management, connection handling, and profile viewing capabilities in a clean, maintainable architecture.

## Key Improvements

### Backend Improvements

1. **Database Utilities Consolidation**
   - Combined multiple utility scripts into a unified `database_utils.py`
   - Created a structured `DatabaseUtils` class with comprehensive methods for database operations
   - Added proper error handling and connection management
   - Implemented a command-line interface for easier utility execution

2. **Documentation Enhancements**
   - Updated README files with clearer project structure information
   - Improved API endpoint documentation
   - Enhanced setup instructions

### iOS Client Improvements

1. **Code Organization**
   - Extracted UI components into a dedicated `UIComponents.swift` file
   - Split large views into smaller, more manageable components
   - Separated `UserListRow.swift` and `UserDetailView.swift` from ContentView
   - Consolidated all models into a single `Models.swift` file
   - Flattened directory structure by moving all files to the main directory

2. **UI Component Library**
   - Implemented reusable button styles (`PrimaryButtonStyle`, `SecondaryButtonStyle`)
   - Created standard UI components (`UserAvatar`, `InfoRow`, `SectionCard`)
   - Added state handling views (`LoadingView`, `ErrorView`, `EmptyStateView`)

3. **View Refactoring**
   - Refactored `HomeView` to use the new component library
   - Enhanced `UserListView` with improved search and error states
   - Updated `UserDetailView` with better connection management
   - Streamlined `ContentView` to focus on navigation coordination

## Architecture Highlights

### Backend

- **Flask-based RESTful API**: Clean separation of routes and database operations
- **PostgreSQL Database**: Robust data storage with proper connection management
- **Utility Scripts**: Consolidated database management utilities

### iOS Client

- **MVVM + Coordinator Pattern**: Clean separation of concerns
- **SwiftUI Framework**: Modern declarative UI development
- **Centralized State Management**: Via AppCoordinator
- **Reusable Component Library**: UI consistency and maintainability
- **Flat File Structure**: Simpler navigation with all files in the main directory

## Features

- **User Management**:
  - Create, read, update, and delete user profiles
  - Search for users by name, university, location, or interests
  - Comprehensive user profiles with personal and professional details

- **Connection Management**:
  - Bidirectional connections between users with relationship types
  - View and manage user connections
  - Automatic relationship synchronization

- **Authentication**:
  - Secure login system with username/password authentication
  - User-specific data access
  - Persistent login with UserDefaults storage

- **Modern UI**:
  - Clean, responsive SwiftUI interface
  - Proper loading states and error handling
  - Retry mechanisms for failed network requests

## Project Structure

```
nexus/
├── database_code/                # Backend database code
│   ├── api.py                    # Flask API server
│   ├── config.py                 # Configuration settings
│   ├── createDatabase.py         # Database schema creation
│   ├── database_operations.py    # Core database operations
│   ├── database_utils.py         # Database maintenance utilities
│   ├── insertSampleUsers.py      # Sample user data insertion
│   ├── insertSampleRelationships.py # Sample relationship data
│   ├── setup.py                  # One-step setup script
│   ├── test_api.py               # API testing script
│   └── README.md                 # Database code documentation
├── requirements.txt              # Python dependencies
└── swift_code/                   # iOS client application
    └── nexus/                    # Main app code
        ├── AppCoordinator.swift  # Navigation and state management
        ├── Models.swift          # Combined data models
        ├── NetworkManager.swift  # API communication
        ├── ContentView.swift     # Container view
        ├── HomeView.swift        # Home screen
        ├── UserListView.swift    # User listing
        ├── UserListRow.swift     # User list items
        ├── UserDetailView.swift  # User detail view
        ├── EditProfileView.swift # Profile editing
        ├── LoginView.swift       # Authentication UI
        ├── UIComponents.swift    # Reusable UI components
        └── NexusApp.swift        # App entry point
```

## Getting Started

### Backend Setup

1. **Install Dependencies**
   ```
   pip install -r requirements.txt
   ```

2. **Set Up Database**
   ```
   cd database_code
   python setup.py
   ```
   This script creates the database schema and populates it with sample data.

3. **Start API Server**
   ```
   cd database_code
   python api.py
   ```

4. **API Endpoints**

   | Endpoint | Method | Description |
   |----------|--------|-------------|
   | `/users` | GET | List all users |
   | `/users` | POST | Create a new user |
   | `/users/{user_id}` | GET | Get user by ID |
   | `/users/{user_id}` | PUT | Update a user |
   | `/users/{username}` | GET | Get user by username |
   | `/users/search?term={search_term}` | GET | Search for users |
   | `/users/{user_id}/connections` | GET | Get user connections |
   | `/connections` | POST | Create a new connection |
   | `/connections` | DELETE | Remove a connection |
   | `/login` | POST | Create login credentials |
   | `/login/validate` | POST | Validate user credentials |

### iOS Client Setup

1. **Configure Network Settings**
   - Open `swift_code/nexus/NetworkManager.swift`
   - For simulator: URL is already set to `127.0.0.1:8080`
   - For physical device: Update IP address to your Mac's IP

2. **Run in Xcode**
   - Open the project in Xcode
   - Select a device or simulator
   - Run the application (⌘+R)

## Database Utilities

The project includes a consolidated utility script for database management:

```
cd database_code
python database_utils.py [command] [args]
```

Available commands:

- `check` - View current database state
- `passwords [password]` - Update all user passwords
- `clean [threshold]` - Remove test data
- `login <user_id> <username> <password>` - Ensure a specific user has login credentials

## Testing

Run the comprehensive API test suite:

```
cd database_code
python test_api.py
```

This tests:
- API endpoints
- Database operations
- Connection management
- User authentication

## Future Enhancement Opportunities

1. **Backend**
   - Implement authentication middleware
   - Add pagination for large data sets
   - Create comprehensive test suite
   - Add user profile image support

2. **iOS Client**
   - Implement offline mode with local caching
   - Add push notifications
   - Enhance user profile editing

## Key Technologies

### Backend
- **Python 3.9+**
- **Flask** - Web framework
- **PostgreSQL** - Relational database
- **psycopg2** - PostgreSQL adapter

### iOS Client
- **Swift 5.7+**
- **SwiftUI** - Declarative UI
- **Combine** - Reactive programming
- **MVVM + Coordinator** - Architecture pattern

## Contributors

- Daniel Tantsyura
- Contributions welcome!

## License

This project is available under the MIT License.
