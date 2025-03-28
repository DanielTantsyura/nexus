## Database Management Scripts

This repository contains scripts for setting up and interacting with the Nexus application database.

### 1. Database Setup (`createDatabase.py`)

The `createDatabase.py` script initializes the PostgreSQL database with the necessary schema for the Nexus application. This script:

1. Connects to a PostgreSQL database hosted on Railway
2. Creates a `users` table that stores:
   - Basic user information (name, username, email, phone number)
   - Educational details (high school, university)
   - Professional details (field of interest, current company)
   - Location and personal information

3. Creates a `relationships` table that tracks connections between users with:
   - References to both users in the relationship
   - Description of how they are connected
   - Timestamp of when the connection was established

### 2. Sample Data (`insertSampleUsers.py` and `insertSampleRelationships.py`)

The repository includes scripts to populate the database with sample data:

- `insertSampleUsers.py`: Inserts sample user profiles into the database
  - Creates user records with names, contact information, and educational backgrounds
  - Each user has unique attributes like fields of interest and locations

- `insertSampleRelationships.py`: Creates relationships between the sample users
  - Establishes connections between users (e.g., Daniel knows everyone, Max knows Soren)
  - Adds descriptive information about each relationship

### 3. Database Operations (`database_operations.py`)

The `database_operations.py` script serves as a comprehensive example of how to interact with the Nexus database from an application. This file provides:

#### Database Manager Class
A reusable `DatabaseManager` class that encapsulates all database operations:

- **Connection Management**
  - Methods to connect to and disconnect from the database
  - Transaction handling with commit and rollback support

- **User Operations**
  - `get_all_users()`: Retrieves all users from the database
  - `get_user_by_username(username)`: Finds a specific user by their username
  - `search_users(search_term)`: Searches for users by various criteria
  - `add_user(user_data)`: Adds a new user to the database
  - `update_user(user_id, user_data)`: Updates an existing user's information

- **Relationship Management**
  - `get_user_connections(user_id)`: Gets all connections for a specific user
  - `add_connection(user_id, contact_id, description)`: Creates a new connection
  - `remove_connection(user_id, contact_id)`: Removes an existing connection

#### Usage Examples
The script includes working examples of:
- Listing all users in the database
- Searching for users by location
- Looking up a specific user's profile
- Displaying a user's connections
- Adding new users and relationships (commented out to prevent accidental data insertion)

### Using the Database Manager in Your Application

To integrate the `DatabaseManager` into your application:

```python
from database_operations import DatabaseManager

# Create a database manager instance
db = DatabaseManager()

# Connect to the database
db.connect()

try:
    # Example: Search for users in New York
    ny_users = db.search_users("New York")
    
    # Example: Get a user's connections
    user = db.get_user_by_username("danieltantsyura")
    if user:
        connections = db.get_user_connections(user['id'])
finally:
    # Always disconnect when done
    db.disconnect()
```
