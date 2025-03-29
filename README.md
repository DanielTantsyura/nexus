# Nexus Application

A modern social networking application that allows users to manage connections with others, featuring a Flask backend API and a native iOS client with SwiftUI.

## Features

- **User Management**:
  - Create, read, update, and delete user profiles
  - Search for users by name, university, location, or interests
  - Comprehensive user profiles with personal and professional details

- **Connection Management**:
  - Bidirectional connections between users with relationship types
  - Connection management with intuitive UI
  - Automatic relationship synchronization

- **Authentication**:
  - Simple login system with username/password authentication
  - User-specific data access
  - Secure credential storage

- **Modern UI**:
  - Clean, responsive SwiftUI interface
  - Consistent design language
  - Proper loading states and error handling

## Project Structure

```
nexus/
├── api.py                       # Flask API server
├── app_test.py                  # Comprehensive test script
├── config.py                    # Configuration settings
├── createDatabase.py            # Database initialization script
├── database_operations.py       # Core database operations
├── database_utils.py            # Database utilities for maintenance
├── requirements.txt             # Python dependencies
├── setup.py                     # One-step setup script
├── swift_code/                  # iOS client application
│   ├── nexus/                   # Main app code
│   │   ├── App/                 # App architecture
│   │   ├── Models/              # Data models
│   │   ├── ContentView.swift    # Main views
│   │   ├── NetworkManager.swift # API communication
│   │   └── NexusApp.swift       # Main app entry point
│   └── nexus.xcodeproj/         # Xcode project files
└── test_api.py                  # API testing script
```

## Getting Started

### Backend Setup

1. **Install Dependencies**
   ```
   pip install -r requirements.txt
   ```

2. **Set Up Database**
   ```
   python setup.py
   ```
   This script creates the database schema and populates it with sample data.

3. **Start API Server**
   ```
   python api.py
   ```

4. **API Endpoints**

   | Endpoint | Method | Description |
   |----------|--------|-------------|
   | `/users` | GET | List all users |
   | `/users` | POST | Create a new user |
   | `/users/{user_id}` | PUT | Update a user |
   | `/users/{username}` | GET | Get a specific user |
   | `/users/search?term={search_term}` | GET | Search for users |
   | `/users/{user_id}/connections` | GET | Get user connections |
   | `/connections` | POST | Create a new connection |
   | `/connections` | DELETE | Remove a connection |
   | `/login` | POST | Create login credentials |
   | `/login/validate` | POST | Validate user credentials |

### iOS Client Setup

1. **Configure Network Settings**
   - Open `NetworkManager.swift`
   - For simulator: URL is already set to `127.0.0.1`
   - For physical device: Update IP address to your Mac's IP

2. **Run in Xcode**
   - Open `swift_code/nexus.xcodeproj`
   - Select a device or simulator
   - Run the application (⌘+R)

## Database Utilities

The project includes a consolidated utility script for database management:

```
python database_utils.py [command] [args]
```

Available commands:

- `check` - View current database state
- `passwords [password]` - Update all user passwords
- `clean [threshold]` - Remove test data
- `login <user_id> <username> <password>` - Ensure a specific user has login credentials

## Testing

Run the comprehensive test suite:

```
python app_test.py
```

This tests the entire application including:
- Database operations
- API endpoints
- Connection management
- User authentication

For API-specific tests:

```
python test_api.py
```

## Key Technologies

### Backend
- **Python 3.9+**
- **Flask** - Lightweight web framework
- **PostgreSQL** - Relational database
- **psycopg2** - PostgreSQL adapter

### iOS Client
- **Swift 5.7+**
- **SwiftUI** - Declarative UI framework
- **Combine** - Reactive programming
- **MVVM + Coordinator** - Architecture pattern

## Contributors

- Daniel Tantsyura
- Contributions welcome!

## License

This project is available under the MIT License.
