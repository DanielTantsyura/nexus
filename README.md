# Nexus Application

Nexus is a personal network management system with a Python Flask backend and a Swift iOS frontend. It helps users maintain an organized database of their personal and professional connections.

## Overview

Nexus consists of two main components:
1. A PostgreSQL database with a Flask API backend
2. A native iOS client built with SwiftUI

The system allows users to:
- Create and manage detailed contact profiles
- Add new contacts using natural language processing
- Tag and categorize connections
- Track relationship information and notes

## Key Features

### Backend Features

1. **Database Structure**
   - PostgreSQL with three primary tables: `people`, `logins`, and `relationships`
   - Comprehensive user profiles with personal and professional details
   - Relationship tracking with custom notes and tags
   - Last login timestamp tracking
   - Non-unique email addresses, allowing multiple users with the same email

2. **Natural Language Contact Creation**
   - OpenAI GPT integration via `newUser.py` module
   - Free-form text parsing into structured user data
   - Smart field extraction (names, universities, interests, etc.)
   - Automatic relationship creation with appropriate tags

3. **API Endpoints**
   - RESTful Flask API with comprehensive error handling
   - User CRUD operations (Create, Read, Update, Delete)
   - Connection management with bidirectional relationship support
   - Search functionality across multiple user fields
   - Simplified login credential creation with auto-generated usernames

### iOS Client Features

1. **Modern SwiftUI Interface**
   - Tab-based navigation with Network and Profile sections
   - User detail views with comprehensive profile information
   - Connection management directly from user profiles
   - Form-based contact and profile editing

2. **State Management**
   - Centralized state via NetworkManager and AppCoordinator
   - Reactive UI updates through published properties
   - Persistent login with UserDefaults
   - Clean error handling and loading states

3. **Network Communication**
   - Robust API client with standardized error handling
   - Automatic retry for failed network requests
   - Support for simulator and physical device testing
   - Comprehensive data models that map directly to API responses

## Architecture

### Backend Architecture

- **Database Layer**
   - `createDatabase.py` - Sets up the PostgreSQL schema
   - `database_operations.py` - Unified class for all database operations
   - `database_utils.py` - Helper utilities for database interactions

- **API Layer**
   - `api.py` - Flask server with RESTful endpoints
   - `config.py` - Environment-based configuration
   - Comprehensive error handling and response formatting

- **Natural Language Processing**
   - `newUser.py` - OpenAI GPT integration for text processing
   - Structured user data extraction from free-form descriptions
   - Integration with database operations for seamless contact creation

### iOS Client Architecture

- **Data Models**
   - `Models.swift` - Core data structures that match API responses
   - `User`, `Connection`, `Login` and other model types
   - Proper Codable implementation for JSON serialization

- **Network Layer**
   - `NetworkManager.swift` - Handles all API communication
   - Published properties for reactive UI updates
   - Comprehensive error handling and retry mechanisms
   - Session management with persistent login

- **UI Layer**
   - `MainTabView.swift` - Tab-based main navigation
   - `UserListView.swift`, `UserDetailView.swift`, etc. - Primary UI components
   - `UIComponents.swift` - Reusable UI elements
   - `AppCoordinator.swift` - Centralized navigation and state management

## Database Features

### User Profiles

The `people` table stores comprehensive information about each contact:
- Basic info: name, email, phone, location
- Professional details: company, job title, field of interest
- Educational background: university, major, high school
- Personal details: gender, ethnicity, birthday
- Recent tags for quick access to frequently used categories

Email addresses are not required to be unique, allowing the system to store multiple contacts with the same email address.

### Relationship Management

The `relationships` table manages connections between people:
- Bidirectional relationship tracking
- Custom notes specific to each relationship
- Tag-based categorization with comma-separated tags
- Last viewed timestamp for tracking recent interactions
- One-to-many relationship model that allows each user to have their own perspective

### Authentication System

The login system features a streamlined credential creation process:
- Usernames are automatically generated from the user's first and last names
- If a username already exists, a random number (1-100) is appended
- This process repeats until a unique username is found
- Simple API endpoint that handles credential creation transparently

### Natural Language Processing

The system leverages OpenAI's API to extract structured data from natural language:
- Free-form text descriptions converted to proper database fields
- Smart extraction of educational institutions
- Detection of interests and professional details
- Demographic information parsing
- Fallback to basic extraction if API processing fails

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
   | `/people` | GET | List all people |
   | `/people` | POST | Create a new user |
   | `/people/<int:user_id>` | GET | Get user by ID |
   | `/people/<int:user_id>` | PUT | Update a user |
   | `/people/search` | GET | Search for people |
   | `/people/<int:user_id>/connections` | GET | Get user connections |
   | `/connections` | POST | Create a new connection |
   | `/connections/update` | PUT | Update a connection |
   | `/contacts/create` | POST | Create a contact from text |
   | `/login` | POST | Create login credentials |
   | `/login/validate` | POST | Validate login credentials |
   | `/login/update` | POST | Update last login timestamp |

### iOS Client Setup

1. **Configure Network Settings**
   - Open `swift_code/nexus/NetworkManager.swift`
   - For simulator: URL is already set to `127.0.0.1:8080`
   - For physical device: Update IP address to your Mac's IP

2. **Run in Xcode**
   - Open the project in Xcode
   - Select a device or simulator
   - Run the application (⌘+R)

## Railway Deployment

Follow these steps to deploy the Nexus API to Railway:

1. **Connect to GitHub**
   - Create a Railway account and connect your GitHub repository

2. **Configure Environment Variables**
   - Add the following environment variables in Railway dashboard:
     - `DATABASE_URL`: Railway will automatically provide this if you add a PostgreSQL service
     - `API_HOST`: Set to `0.0.0.0`
     - `API_DEBUG`: Set to `False` for production
     - `OPENAI_API_KEY`: Your OpenAI API key
     - `DEFAULT_TAGS`: (Optional) Comma-separated list of default tags

3. **Add a PostgreSQL Service**
   - Add a PostgreSQL service to your project in Railway
   - Railway will automatically create the necessary DATABASE_URL

4. **Deploy Your Application**
   - Railway will automatically deploy your application
   - Monitor the deployment logs for any issues

5. **Access Your API**
   - Railway will provide a URL for your deployed API
   - Update your iOS client to use this URL instead of the local development URL

### Troubleshooting Railway Deployment

- **Database Connection Issues**: Make sure the DATABASE_URL is correctly set
- **Deployment Failures**: Check the logs for specific error messages
- **API Not Responding**: Ensure API_HOST is set to `0.0.0.0` and the Procfile is correct
- **Continuous Crashes/Restarts**: If your application keeps crashing and restarting:
  - Check if gunicorn can find your application (if using `database_code.api:app` format doesn't work, try `cd database_code && gunicorn api:app`)
  - Ensure your app correctly reads the PORT variable provided by Railway
  - Verify your database credentials are correct and the database is accessible
  - Look for any import errors in the logs that might indicate missing dependencies

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
