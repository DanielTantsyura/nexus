# Nexus Application

A modern social networking application featuring a Flask backend API and a native iOS client built with SwiftUI. Nexus enables users to create profiles, search for connections, and manage their professional network.

## Overview

Nexus is a modern social networking platform with a Flask-based backend API and a native iOS client. The project implements user management, connection handling, and profile viewing capabilities in a clean, maintainable architecture.

## Key Improvements

### Backend Improvements

1. **Database Operations Consolidation**
   - Consolidated `DatabaseUtils` and `DatabaseManager` into a single comprehensive class
   - Implemented context managers for improved resource management
   - Enhanced error handling throughout all database operations
   - Added bidirectional relationship support with clear separation of one-way and two-way properties
   - Implemented last login tracking for user activity monitoring

2. **API Enhancements**
   - Added command-line arguments for flexible port configuration
   - Improved API response formats with consistent error handling
   - Added endpoints for login tracking and relationship management
   - Better organized endpoints with detailed documentation

3. **Documentation Improvements**
   - Created comprehensive README files with detailed setup instructions
   - Added extensive docstrings to all modules and functions
   - Documented database schema with clear explanation of relationship structure
   - Added troubleshooting guides for common issues

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
- **Comprehensive Database Manager**: Unified class for all database operations
- **Environment Configuration**: Flexible settings via environment variables

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
  - Separate one-way and two-way relationship properties

- **Authentication**:
  - Secure login system with username/password authentication
  - User-specific data access
  - Persistent login with UserDefaults storage
  - Last login tracking for user activity monitoring

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
│   ├── database_operations.py    # Unified database management class
│   ├── newUser.py                # Natural language contact creation
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

2. **Create .env File**
   Create a `.env` file in the project root with:
   ```
   DATABASE_URL=postgresql://username:password@localhost:5432/nexus
   API_PORT=8080
   OPENAI_API_KEY=your_openai_api_key
   ```

3. **Set Up Database**
   ```
   cd database_code
   python setup.py
   ```
   This script creates the database schema and populates it with sample data.

   For setup without sample data:
   ```
   python setup.py --no-samples
   ```

   To customize the default password:
   ```
   python setup.py --password custompassword
   ```

4. **Start API Server**
   ```
   cd database_code
   python api.py
   ```

   To use a custom port:
   ```
   python api.py --port 9000
   ```

5. **API Endpoints**

   | Endpoint | Method | Description |
   |----------|--------|-------------|
   | `/users` | GET | List all users |
   | `/users` | POST | Create a new user |
   | `/users/{user_id}` | GET | Get user by ID |
   | `/users/{user_id}` | PUT | Update a user |
   | `/users/search?q={search_term}` | GET | Search for users |
   | `/connections/{user_id}` | GET | Get user connections |
   | `/connections` | POST | Create a new connection |
   | `/connections` | PUT | Update a connection |
   | `/connections` | DELETE | Remove a connection |
   | `/contacts/create` | POST | Create a contact from text |
   | `/login` | POST | Validate login credentials |
   | `/users/{user_id}/update-last-login` | POST | Update last login timestamp |
   | `/utils/check-database` | GET | Check database state |
   | `/utils/update-passwords` | POST | Update all user passwords |

### iOS Client Setup

1. **Configure Network Settings**
   - Open `swift_code/nexus/NetworkManager.swift`
   - For simulator: URL is already set to `127.0.0.1:8080`
   - For physical device: Update IP address to your Mac's IP

2. **Run in Xcode**
   - Open the project in Xcode
   - Select a device or simulator
   - Run the application (⌘+R)

## Database Features

### Relationship Management

The relationship system supports both one-way and two-way properties:

- **Two-way properties**: `relationship_type` is shared in both directions
- **One-way properties**: `note`, `tags`, and `last_viewed` are specific to each direction

This design allows users to maintain their own perspective on the relationship while sharing a common relationship type.

### Login Tracking

The system tracks when users log in or open the application:

- The `last_login` field in the `logins` table is automatically updated when:
  - A user successfully logs in through the `/login` endpoint
  - The app is opened and calls the `/users/{id}/update-last-login` endpoint

This tracking enables features like showing "last seen" information, detecting inactive accounts, and providing activity analytics.

### Natural Language Processing

The system uses OpenAI's API to extract structured user data from free-form text:

- Process text descriptions into structured user profiles
- Extract additional notes that don't fit standard fields
- Automatically create contacts with proper relationship data

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
   - Support for multiple relationship types
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
- **OpenAI API** - Natural language processing

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
