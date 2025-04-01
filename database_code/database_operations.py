import psycopg2
from psycopg2.extras import RealDictCursor
from typing import List, Dict, Optional, Any, Tuple
from config import DATABASE_URL, DEFAULT_TAGS, MAX_RECENT_TAGS

class DatabaseManager:
    """
    A class to manage database operations for the Nexus application.
    """
    
    def __init__(self, connection_string: str = DATABASE_URL):
        """
        Initialize the DatabaseManager with a connection string.
        
        Args:
            connection_string: PostgreSQL connection string
        """
        self.connection_string = connection_string
        self.connection = None
        self.cursor = None
    
    def connect(self) -> None:
        """
        Establish a connection to the database.
        """
        try:
            self.connection = psycopg2.connect(self.connection_string)
            # Use RealDictCursor to return results as dictionaries
            self.cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            print("Connected to the database.")
        except Exception as e:
            print(f"Error connecting to the database: {e}")
            raise
    
    def disconnect(self) -> None:
        """
        Close the database connection.
        """
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            print("Disconnected from the database.")
    
    def get_all_users(self) -> List[Dict]:
        """
        Retrieve all users from the database.
        
        Returns:
            List of user dictionaries
        """
        query = """
        SELECT * FROM users
        ORDER BY first_name, last_name;
        """
        
        try:
            self.cursor.execute(query)
            users = self.cursor.fetchall()
            return [dict(user) for user in users]
        except Exception as e:
            print(f"Error retrieving users: {e}")
            return []
    
    def get_user_by_username(self, username: str) -> Optional[Dict]:
        """
        Retrieve a user by their username.
        
        Args:
            username: The username to search for
            
        Returns:
            User dictionary or None if not found
        """
        query = """
        SELECT * FROM users
        WHERE username = %s;
        """
        
        try:
            self.cursor.execute(query, (username,))
            user = self.cursor.fetchone()
            return dict(user) if user else None
        except Exception as e:
            print(f"Error retrieving user: {e}")
            return None
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict]:
        """
        Retrieve a user by their ID.
        
        Args:
            user_id: The user ID to search for
            
        Returns:
            User dictionary or None if not found
        """
        query = """
        SELECT * FROM users
        WHERE id = %s;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            user = self.cursor.fetchone()
            return dict(user) if user else None
        except Exception as e:
            print(f"Error retrieving user: {e}")
            return None
    
    def search_users(self, search_term: str) -> List[Dict]:
        """
        Search for users by name, location, or interests.
        
        Args:
            search_term: The term to search for
            
        Returns:
            List of matching user dictionaries
        """
        query = """
        SELECT * FROM users
        WHERE 
            first_name ILIKE %s OR
            last_name ILIKE %s OR
            location ILIKE %s OR
            field_of_interest ILIKE %s OR
            university ILIKE %s OR
            high_school ILIKE %s
        ORDER BY first_name, last_name;
        """
        
        search_pattern = f"%{search_term}%"
        params = (search_pattern, search_pattern, search_pattern, 
                 search_pattern, search_pattern, search_pattern)
        
        try:
            self.cursor.execute(query, params)
            users = self.cursor.fetchall()
            return [dict(user) for user in users]
        except Exception as e:
            print(f"Error searching users: {e}")
            return []
    
    def get_user_connections(self, user_id: int) -> List[Dict]:
        """
        Get all connections for a specific user.
        
        Args:
            user_id: The ID of the user
            
        Returns:
            List of connection dictionaries with user information
        """
        query = """
        SELECT 
            u.id, u.username, u.first_name, u.last_name,
            u.email, u.phone_number, u.location, u.university,
            u.field_of_interest, u.high_school, u.gender, u.ethnicity,
            u.uni_major, u.job_title, u.current_company, u.profile_image_url,
            u.linkedin_url, r.relationship_description, r.custom_note,
            r.tags, r.last_viewed
        FROM relationships r
        JOIN users u ON r.contact_id = u.id
        WHERE r.user_id = %s
        ORDER BY u.first_name, u.last_name;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            connections = self.cursor.fetchall()
            return [dict(connection) for connection in connections]
        except Exception as e:
            print(f"Error retrieving connections: {e}")
            return []
    
    def add_user(self, user_data: Dict[str, Any]) -> int:
        """
        Add a new user to the database.
        
        Args:
            user_data: Dictionary containing user information
            
        Returns:
            ID of the newly created user
        """
        query = """
        INSERT INTO users (
            username, first_name, last_name, email, phone_number,
            location, university, field_of_interest, high_school,
            gender, ethnicity, uni_major, job_title, current_company,
            profile_image_url, linkedin_url, recent_tags
        ) VALUES (
            %(username)s, %(first_name)s, %(last_name)s, %(email)s, %(phone_number)s,
            %(location)s, %(university)s, %(field_of_interest)s, %(high_school)s,
            %(gender)s, %(ethnicity)s, %(uni_major)s, %(job_title)s, %(current_company)s,
            %(profile_image_url)s, %(linkedin_url)s, %(recent_tags)s
        ) RETURNING id;
        """
        
        # Ensure the recent_tags field is present, set to default tags if not provided
        if 'recent_tags' not in user_data or user_data['recent_tags'] is None:
            user_data['recent_tags'] = DEFAULT_TAGS
        
        try:
            self.cursor.execute(query, user_data)
            user_id = self.cursor.fetchone()['id']
            self.connection.commit()
            print(f"User created with ID: {user_id}")
            return user_id
        except Exception as e:
            self.connection.rollback()
            print(f"Error adding user: {e}")
            raise
    
    def add_connection(self, user_id: int, contact_id: int, description: str, custom_note: str = None, tags: str = None) -> bool:
        """
        Add a new connection between two users in both directions.
        
        Args:
            user_id: ID of the first user
            contact_id: ID of the second user
            description: Description of the relationship
            custom_note: Optional detailed note about the connection
            tags: Optional comma-separated tags for the connection
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        INSERT INTO relationships (user_id, contact_id, relationship_description, custom_note, tags, last_viewed)
        VALUES (%s, %s, %s, %s, %s, NOW());
        """
        
        try:
            # First direction: user_id -> contact_id
            self.cursor.execute(query, (user_id, contact_id, description, custom_note, tags))
            
            # Second direction: contact_id -> user_id (create the reciprocal connection)
            self.cursor.execute(query, (contact_id, user_id, description, custom_note, tags))
            
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error adding connection: {e}")
            return False
    
    def remove_connection(self, user_id: int, contact_id: int) -> bool:
        """
        Remove a connection between two users in both directions.
        
        Args:
            user_id: ID of the first user
            contact_id: ID of the second user
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        DELETE FROM relationships
        WHERE (user_id = %s AND contact_id = %s) OR (user_id = %s AND contact_id = %s);
        """
        
        try:
            # Remove connections in both directions
            self.cursor.execute(query, (user_id, contact_id, contact_id, user_id))
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error removing connection: {e}")
            return False

    def update_user(self, user_id: int, user_data: Dict[str, Any]) -> bool:
        """
        Update an existing user in the database.
        
        Args:
            user_id: The ID of the user to update
            user_data: Dictionary containing updated user information
            
        Returns:
            True if update was successful, False otherwise
        """
        # Build the SET clause dynamically based on provided fields
        set_clauses = []
        params = {'id': user_id}
        
        # Map of user_data keys to database columns
        field_mapping = {
            'username': 'username',
            'first_name': 'first_name',
            'last_name': 'last_name',
            'email': 'email',
            'phone_number': 'phone_number',
            'location': 'location',
            'university': 'university',
            'field_of_interest': 'field_of_interest',
            'high_school': 'high_school',
            'gender': 'gender',
            'ethnicity': 'ethnicity',
            'uni_major': 'uni_major',
            'job_title': 'job_title',
            'current_company': 'current_company',
            'profile_image_url': 'profile_image_url',
            'linkedin_url': 'linkedin_url',
            'recent_tags': 'recent_tags'
        }
        
        for key, db_column in field_mapping.items():
            if key in user_data:
                set_clauses.append(f"{db_column} = %({key})s")
                params[key] = user_data[key]
        
        if not set_clauses:
            print("No fields to update")
            return False
        
        query = f"""
        UPDATE users
        SET {', '.join(set_clauses)}
        WHERE id = %(id)s
        """
        
        try:
            self.cursor.execute(query, params)
            rows_affected = self.cursor.rowcount
            self.connection.commit()
            
            if rows_affected > 0:
                print(f"User {user_id} updated successfully")
                return True
            else:
                print(f"No user found with ID {user_id}")
                return False
        except Exception as e:
            self.connection.rollback()
            print(f"Error updating user: {e}")
            return False

    def add_user_login(self, user_id: int, username: str, passkey: str) -> bool:
        """
        Add login credentials for a user.
        
        Args:
            user_id: ID of the user
            username: Login username
            passkey: Password/key for authentication
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        INSERT INTO logins (user_id, username, passkey, last_login)
        VALUES (%s, %s, %s, NOW())
        """
        
        try:
            self.cursor.execute(query, (user_id, username, passkey))
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error adding user login: {e}")
            return False
    
    def validate_login(self, username: str, passkey: str) -> Optional[int]:
        """
        Validate user login credentials.
        
        Args:
            username: Login username
            passkey: Password/key for authentication
            
        Returns:
            User ID if login successful, None otherwise
        """
        query = """
        SELECT user_id
        FROM logins
        WHERE username = %s AND passkey = %s
        """
        
        update_last_login_query = """
        UPDATE logins
        SET last_login = NOW()
        WHERE username = %s AND passkey = %s
        """
        
        try:
            self.cursor.execute(query, (username, passkey))
            result = self.cursor.fetchone()
            
            if result:
                # Update last login timestamp
                self.cursor.execute(update_last_login_query, (username, passkey))
                self.connection.commit()
                
            return result['user_id'] if result else None
        except Exception as e:
            print(f"Error validating login: {e}")
            return None

    def update_connection(self, user_id: int, contact_id: int, data: Dict[str, Any]) -> bool:
        """
        Update a connection with custom notes, tags, or other metadata.
        
        Args:
            user_id: ID of the user
            contact_id: ID of the contact
            data: Dictionary of fields to update (description, custom_note, tags)
            
        Returns:
            True if successful, False otherwise
        """
        # Build the SET clause dynamically based on provided fields
        set_clauses = []
        params = []
        
        for key, value in data.items():
            if key in ['relationship_description', 'custom_note', 'tags']:
                set_clauses.append(f"{key} = %s")
                params.append(value)
        
        # Always update the last_viewed timestamp
        set_clauses.append("last_viewed = NOW()")
        
        # Add user_id and contact_id for the WHERE clause
        params.extend([user_id, contact_id])
        
        query = f"""
        UPDATE relationships
        SET {', '.join(set_clauses)}
        WHERE user_id = %s AND contact_id = %s;
        """
        
        try:
            self.cursor.execute(query, params)
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error updating connection: {e}")
            return False
            
    def update_last_viewed(self, user_id: int, contact_id: int) -> bool:
        """
        Update the last_viewed timestamp for a connection.
        
        Args:
            user_id: ID of the user viewing the connection
            contact_id: ID of the contact being viewed
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        UPDATE relationships
        SET last_viewed = NOW()
        WHERE user_id = %s AND contact_id = %s;
        """
        
        try:
            self.cursor.execute(query, (user_id, contact_id))
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error updating last viewed timestamp: {e}")
            return False

    def get_user_recent_tags(self, user_id: int) -> Optional[List[str]]:
        """
        Get a user's recently used tags.
        
        Args:
            user_id: The ID of the user
            
        Returns:
            List of recent tags or None if not found
        """
        query = """
        SELECT recent_tags FROM users
        WHERE id = %s;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            result = self.cursor.fetchone()
            
            if result and result['recent_tags']:
                # Convert the comma-separated string to a list
                return result['recent_tags'].split(',')
            return []
        except Exception as e:
            print(f"Error retrieving recent tags: {e}")
            return []
    
    def update_user_recent_tags(self, user_id: int, new_tags: List[str], max_tags: int = MAX_RECENT_TAGS) -> bool:
        """
        Update a user's recently used tags.
        
        Args:
            user_id: The ID of the user
            new_tags: List of new tags to add to the recent tags
            max_tags: Maximum number of tags to keep in the recent tags list
            
        Returns:
            True if update was successful, False otherwise
        """
        # First, get the current recent tags
        current_tags = self.get_user_recent_tags(user_id)
        
        # Create a unique list of tags with new tags at the front
        updated_tags = []
        
        # Add new tags first (if they're not already in the current tags)
        for tag in new_tags:
            if tag and tag not in updated_tags and tag not in current_tags:
                updated_tags.append(tag)
        
        # Then add existing tags
        for tag in current_tags:
            if tag and tag not in updated_tags:
                updated_tags.append(tag)
        
        # Limit to max_tags
        updated_tags = updated_tags[:max_tags]
        
        # Convert list to comma-separated string
        tags_string = ','.join(updated_tags) if updated_tags else None
        
        # Update the user record
        query = """
        UPDATE users
        SET recent_tags = %s
        WHERE id = %s
        """
        
        try:
            self.cursor.execute(query, (tags_string, user_id))
            self.connection.commit()
            
            if self.cursor.rowcount > 0:
                print(f"Recent tags updated for user {user_id}")
                return True
            else:
                print(f"No user found with ID {user_id}")
                return False
        except Exception as e:
            self.connection.rollback()
            print(f"Error updating recent tags: {e}")
            return False


# Example usage
if __name__ == "__main__":
    db = DatabaseManager()
    
    try:
        db.connect()
        
        # Example 1: Get all users
        print("\n--- All Users ---")
        users = db.get_all_users()
        for user in users:
            print(f"{user['first_name']} {user['last_name']} - {user['university']}")
        
        # Example 2: Search for users
        search_term = "New York"
        print(f"\n--- Users in {search_term} ---")
        ny_users = db.search_users(search_term)
        for user in ny_users:
            print(f"{user['first_name']} {user['last_name']} - {user['location']}")
        
        # Example 3: Get user by username
        username = "danieltantsyura"
        print(f"\n--- User Profile for {username} ---")
        user = db.get_user_by_username(username)
        if user:
            print(f"Name: {user['first_name']} {user['last_name']}")
            print(f"Email: {user['email']}")
            print(f"Phone: {user['phone_number']}")
            print(f"Location: {user['location']}")
            print(f"University: {user['university']}")
            print(f"Interests: {user['field_of_interest']}")
            
            # Example 4: Get user's connections
            print("\n--- Connections ---")
            connections = db.get_user_connections(user['id'])
            for conn in connections:
                print(f"{conn['first_name']} {conn['last_name']} - {conn['relationship_description']}")
        
        # Example 5: Adding a new user (commented out to prevent actual insertion)
        """
        new_user = {
            "username": "johndoe",
            "first_name": "John",
            "last_name": "Doe",
            "email": "john.doe@example.com",
            "phone_number": "5551234567",
            "location": "Boston, Massachusetts",
            "university": "MIT",
            "field_of_interest": "Artificial Intelligence, Robotics",
            "high_school": "Boston Latin School"
        }
        new_user_id = db.add_user(new_user)
        print(f"\nAdded new user with ID: {new_user_id}")
        """
        
        # Example 6: Adding a new connection (commented out to prevent actual insertion)
        """
        user_id = 1  # Daniel's ID
        contact_id = 2  # Soren's ID
        db.add_connection(user_id, contact_id, "Met at a coding hackathon")
        print(f"\nAdded new connection between users {user_id} and {contact_id}")
        """
        
    finally:
        db.disconnect() 



"""
Example Output:


Connected to the database.

--- All Users ---
Corwin Cheung - Harvard
Daniel Tantsyura - CMU
Max Battaglia - CMU
Soren Dupont - CMU
Stan Osipenko - CMU

--- Users in New York ---
Corwin Cheung - NYC, New York
Daniel Tantsyura - Westchester, New York
Soren Dupont - Brooklyn, New York

--- User Profile for danieltantsyura ---
Name: Daniel Tantsyura
Email: dan.tantsyura@gmail.com
Phone: 2033135627
Location: Westchester, New York
University: CMU
Interests: Business, Investing, Networking, Long Term Success

--- Connections ---
Corwin Cheung - Daniel knows Corwin
Max Battaglia - Daniel knows Max
Soren Dupont - Daniel knows Soren
Stan Osipenko - Daniel knows Stan
Disconnected from the database.


"""