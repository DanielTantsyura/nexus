# Nexus Application

A social networking application that allows users to manage connections with others.

## Features

- **User Management**:
  - Create, read, update, and delete user profiles
  - Search for users by name, university, or location
  - View detailed user profiles

- **Connection Management**:
  - Create connections between users with relationship types
  - View user connections with relationship details
  - Remove connections with a single tap

- **API Endpoints**:
  - RESTful API with Flask
  - Comprehensive endpoints for users and connections
  - API documentation at `/docs` endpoint

- **iOS Client**:
  - Native Swift client with SwiftUI
  - Clean architecture with MVVM and Coordinator pattern
  - Responsive UI with proper loading states
  - Pull-to-refresh and search functionality

## Project Structure

```
nexus/
├── app_test.py             # Comprehensive test script for entire application
├── api.py                  # Flask API server
├── config.py               # Configuration settings
├── createDatabase.py       # Database initialization script
├── database_operations.py  # Core database functions
├── insertSampleRelationships.py  # Sample data script for relationships
├── insertSampleUsers.py    # Sample data script for users
├── requirements.txt        # Python dependencies
├── setup.py                # One-step setup script
├── test_local_connection.py # API testing script
└── swift_code/nexus/       # iOS client application
    ├── NexusApp.swift      # Main app entry point
    ├── ContentView.swift   # Main views
    ├── NetworkManager.swift # API communication
    ├── Models/             # Data models
    │   ├── User.swift
    │   └── Connection.swift
    └── App/                # App architecture
        └── AppCoordinator.swift
```

## Getting Started

### Backend Setup

1. Install required dependencies:
   ```
   pip install -r requirements.txt
   ```

2. Set up the database and sample data:
   ```
   python setup.py
   ```

3. Start the API server:
   ```
   python api.py
   ```

4. Access the API at:
   - http://localhost:8080/users
   - http://localhost:8080/users/{user_id}
   - http://localhost:8080/users/search?term={search_term}
   - http://localhost:8080/users/{user_id}/connections
   - http://localhost:8080/connections

### iOS Client Setup

See the [iOS App README](swift_code/nexus/README.md) for details on setting up and running the iOS client application.

## Testing

Run the comprehensive test suite to verify functionality:

```
python app_test.py
```

This will test the database setup, API connectivity, and all core operations.

## Key Technologies

- **Backend**:
  - Python Flask for API
  - PostgreSQL database
  - SQLAlchemy ORM

- **iOS**:
  - Swift 5.x
  - SwiftUI framework
  - Combine for reactive updates
  - MVVM + Coordinator architecture
