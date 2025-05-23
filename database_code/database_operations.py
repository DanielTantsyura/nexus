"""
Database operations for the Nexus application.

This module provides a comprehensive class for interacting with the database,
including user management, relationship handling, and utility functions.
"""

import psycopg2
import psycopg2.extras
from typing import Dict, List, Any, Optional, Tuple
from config import DATABASE_URL, MAX_RECENT_TAGS, DEFAULT_TAGS
import time
import traceback

class DatabaseManager:
    """
    Manages database operations for the Nexus application.
    Simplified version with basic connection management.
    """

    def __init__(self, connection_string: str = DATABASE_URL):
        """Initialize the database manager with a connection string."""
        try:
            self.connection_string = connection_string
            print(f"Initializing DatabaseManager with connection string (partially hidden): {connection_string[:20]}...")
            # Test connection to database
            self.connection = None
            self.cursor = None
            self.connect()
            print("Database connection successful!")
        except Exception as e:
            print(f"ERROR initializing database connection: {str(e)}")
            traceback.print_exc()
            # Don't raise here to allow the API to start even with db issues
            self.connection = None
            self.cursor = None
        
    def connect(self) -> bool:
        """
        Establishes a connection to the database.
        Includes simple retry logic.
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        max_retries = 3
        retry_count = 0
        
        while retry_count <= max_retries:
            try:
                print(f"Connection attempt {retry_count + 1}/{max_retries + 1}...")
                self._connect()
                self.cursor = self.connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
                return True
            except psycopg2.Error as e:
                retry_count += 1
                print(f"Connection attempt {retry_count} failed: {e}")
                time.sleep(1)  # Wait a second before retry
                
                if retry_count > max_retries:
                    print(f"Failed to connect to database after {max_retries} attempts")
                    return False
        
        return False
    
    def _connect(self):
        """Establish a connection to the database."""
        try:
            if self.connection is None or self.connection.closed:
                self.connection = psycopg2.connect(self.connection_string)
                self.connection.autocommit = False
        except Exception as e:
            print(f"Error connecting to database: {str(e)}")
            traceback.print_exc()
            raise
    
    def disconnect(self) -> None:
        """Close the database connection and cursor."""
        try:
            if self.cursor:
                self.cursor.close()
            if self.connection:
                self.connection.close()
            self.cursor = None
            self.connection = None
        except Exception as e:
            print(f"Error disconnecting from database: {e}")
    
    def is_connected(self) -> bool:
        """Check if the database connection is active."""
        if not self.connection:
            return False
        
        try:
            # Simple connection check
            self.cursor.execute("SELECT 1")
            return True
        except Exception:
            return False
            
    def execute_query(self, query: str, params=None, fetch=False, fetch_all=False):
        """
        Execute a query with simple retry logic.
        
        Args:
            query: SQL query to execute
            params: Parameters for the query
            fetch: Whether to fetch a single result
            fetch_all: Whether to fetch all results
            
        Returns:
            Query results if fetch is True, otherwise None
        """
        max_retries = 2
        retry_count = 0
        
        while retry_count <= max_retries:
            try:
                self.cursor.execute(query, params)
                
                if fetch_all:
                    return self.cursor.fetchall()
                elif fetch:
                    return self.cursor.fetchone()
                else:
                    self.connection.commit()
                    return True
            except psycopg2.Error as e:
                retry_count += 1
                print(f"Query execution attempt {retry_count} failed: {e}")
                
                # If connection was lost, try to reconnect
                if "connection" in str(e).lower():
                    self.disconnect()
                    self.connect()
                
                if retry_count > max_retries:
                    print(f"Failed to execute query after {max_retries} attempts")
                    return None
        
        return None
    
    # ========== USER MANAGEMENT ==========
    
    def get_all_users(self) -> List[Dict]:
        """
        Get all users from the database.
        
        Returns:
            List of user dictionaries
        """
        query = """
        SELECT * FROM people
        """
        
        try:
            self.cursor.execute(query)
            users = self.cursor.fetchall()
            return [dict(user) for user in users]
        except Exception as e:
            print(f"Error retrieving users: {e}")
            return []
    
    def get_user_by_id(self, user_id: int) -> Optional[Dict]:
        """
        Get a user by ID.
        
        Args:
            user_id: The ID of the user
            
        Returns:
            User dictionary or None if not found
        """
        query = """
        SELECT * FROM people
        WHERE id = %s;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            user = self.cursor.fetchone()
            return dict(user) if user else None
        except Exception as e:
            print(f"Error retrieving user: {e}")
            return None
    
    def get_user_by_username(self, username: str) -> Optional[Dict]:
        """
        Get a user by username.
        
        Args:
            username: The username to look up
            
        Returns:
            User dictionary or None if not found
        """
        query = """
        SELECT * FROM people
        WHERE username = %s;
        """
        
        try:
            self.cursor.execute(query, (username,))
            user = self.cursor.fetchone()
            return dict(user) if user else None
        except Exception as e:
            print(f"Error retrieving user by username: {e}")
            return None
    
    def get_user_by_email(self, email: str) -> Optional[Dict]:
        """
        Get a user by email.
        
        Args:
            email: The email to look up
            
        Returns:
            User dictionary or None if not found
        """
        query = """
        SELECT * FROM people
        WHERE email = %s;
        """
        
        try:
            self.cursor.execute(query, (email,))
            user = self.cursor.fetchone()
            return dict(user) if user else None
        except Exception as e:
            print(f"Error retrieving user by email: {e}")
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
        SELECT * FROM people
        WHERE 
            first_name ILIKE %s OR
            last_name ILIKE %s OR
            location ILIKE %s OR
            interests ILIKE %s OR
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
    
    def add_user(self, user_data: Dict[str, Any]) -> int:
        """
        Add a new user to the database.
        
        Args:
            user_data: Dictionary containing user information
            
        Returns:
            ID of the newly created user
        """
        # Extract username for login creation but don't include it in people table
        username = user_data.pop('username', None)
        password = user_data.pop('password', None)
        
        # Fixed query that doesn't include username column
        query = """
        INSERT INTO people (
            first_name, last_name, email, phone_number,
            location, university, interests, high_school,
            gender, ethnicity, uni_major, job_title, current_company,
            profile_image_url, linkedin_url, recent_tags
        ) VALUES (
            %(first_name)s, %(last_name)s, %(email)s, %(phone_number)s,
            %(location)s, %(university)s, %(interests)s, %(high_school)s,
            %(gender)s, %(ethnicity)s, %(uni_major)s, %(job_title)s, %(current_company)s,
            %(profile_image_url)s, %(linkedin_url)s, %(recent_tags)s
        ) RETURNING id;
        """
        
        # Ensure the recent_tags field is present, set to default tags if not provided
        if 'recent_tags' not in user_data or user_data['recent_tags'] is None:
            user_data['recent_tags'] = DEFAULT_TAGS
        
        # Ensure all required fields exist in the data
        for field in ['first_name', 'last_name', 'email', 'phone_number',
                     'location', 'university', 'interests', 'high_school',
                     'gender', 'ethnicity', 'uni_major', 'job_title', 'current_company',
                     'profile_image_url', 'linkedin_url']:
            if field not in user_data:
                user_data[field] = None
        
        try:
            print(f"Executing SQL: {query}")
            print(f"With values: {user_data}")
            
            self.cursor.execute(query, user_data)
            user_id = self.cursor.fetchone()['id']
            
            # Fix: Use self.connection.commit() instead of self.conn.commit()
            self.connection.commit()
            
            # Add login if username and password were provided
            if username and password:
                self.add_user_login(user_id, username, password)
                
            print(f"User created with ID: {user_id}")
            return user_id
        except Exception as e:
            self.connection.rollback()
            print(f"Error adding user: {e}")
            traceback.print_exc()  # Print the full traceback for debugging
            raise
    
    def update_user(self, user_id: int, user_data: dict) -> bool:
        """
        Update a user with new data.
        
        Args:
            user_id: The ID of the user to update
            user_data: A dictionary of user data to update
            
        Returns:
            True if the update was successful, False otherwise
        """
        try:
            # Check if user exists
            if not self.get_user_by_id(user_id):
                return False
            
            valid_fields = [
                'first_name', 'last_name', 'email', 'phone_number', 'location',
                'university', 'uni_major', 'interests', 'high_school', 'gender',
                'ethnicity', 'job_title', 'current_company', 'profile_image_url',
                'linkedin_url', 'birthday'
            ]
            
            # Filter to only valid fields
            update_data = {k: v for k, v in user_data.items() if k in valid_fields}
            
            if not update_data:
                return True  # Nothing to update, but not an error
            
            # Build SET clause
            set_clause = ', '.join([f"{field} = %s" for field in update_data.keys()])
            values = list(update_data.values())
            values.append(user_id)  # Add user_id for WHERE clause
            
            query = f"""
            UPDATE people
            SET {set_clause}
            WHERE id = %s
            """
            
            with self.connection.cursor() as cursor:
                cursor.execute(query, values)
                self.connection.commit()
                
                return cursor.rowcount > 0
        except Exception as e:
            print(f"Error updating user: {e}")
            self.connection.rollback()
            raise
    
    # ========== RELATIONSHIP MANAGEMENT ==========
    
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
            u.id, l.username, u.first_name, u.last_name,
            u.email, u.phone_number, u.location, u.university,
            u.interests, u.high_school, u.gender, u.ethnicity,
            u.uni_major, u.job_title, u.current_company, u.profile_image_url,
            u.birthday, u.linkedin_url, r.relationship_description, r.notes as custom_note,
            r.tags, r.what_they_are_working_on, r.last_viewed, r.created_at
        FROM people u
        JOIN relationships r ON u.id = r.contact_id
        LEFT JOIN logins l ON u.id = l.people_id
        WHERE r.user_id = %s
        ORDER BY r.last_viewed DESC NULLS LAST, u.first_name, u.last_name;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            connections = self.cursor.fetchall()
            return [dict(conn) for conn in connections]
        except Exception as e:
            print(f"Error retrieving user connections: {e}")
            return []
    
    def add_connection(self, user_id: int, contact_id: int, relationship_description: str, 
                       notes: str = None, tags: str = None, what_they_are_working_on: str = None) -> bool:
        """
        Add a new connection between two users.
        One-directional: only from user_id to contact_id
        
        Args:
            user_id: ID of the first user
            contact_id: ID of the second user
            relationship_description: Type of the relationship
            notes: Optional detailed note about the connection
            tags: Optional comma-separated tags for the connection
            what_they_are_working_on: Optional description of what the contact is currently working on
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        INSERT INTO relationships (user_id, contact_id, relationship_description, notes, tags, what_they_are_working_on, last_viewed)
        VALUES (%s, %s, %s, %s, %s, %s, NOW());
        """
        
        try:
            # Create the one-way relationship: user_id -> contact_id
            self.cursor.execute(query, (user_id, contact_id, relationship_description, notes, tags, what_they_are_working_on))
            
            self.connection.commit()
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error adding connection: {e}")
            return False
    
    def remove_connection(self, user_id: int, contact_id: int) -> bool:
        """
        Remove a connection between two users (one-way only).
        If the contact doesn't have login credentials and is not referenced as a contact
        by any other user, the contact will also be deleted from the people table.
        
        Args:
            user_id: ID of the first user
            contact_id: ID of the second user
            
        Returns:
            True if successful, False otherwise
        """
        query = """
        DELETE FROM relationships
        WHERE user_id = %s AND contact_id = %s;
        """
        
        try:
            # Remove the one-way connection
            self.cursor.execute(query, (user_id, contact_id))
            self.connection.commit()

            print("WE ARE REMOVING A CONNECTION")
            
            # Check if this contact should be deleted completely
            # 1. Check if contact has login credentials (is a real user)
            has_login = self.user_has_login(contact_id)
            
            if not has_login:
                # 2. Check if contact is referenced by any other user
                check_query = """
                SELECT COUNT(*) AS connection_count
                FROM relationships
                WHERE contact_id = %s;
                """
                self.cursor.execute(check_query, (contact_id,))
                result = self.cursor.fetchone()
                
                # If connection count is 0, no one references this contact anymore
                if result and result['connection_count'] == 0:
                    # Delete the contact from the people table
                    delete_query = """
                    DELETE FROM people
                    WHERE id = %s;
                    """
                    self.cursor.execute(delete_query, (contact_id,))
                    self.connection.commit()
                    print(f"Deleted contact {contact_id} from people table as it was a hanging node.")
            
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error removing connection: {e}")
            return False
    
    def update_connection(self, user_id: int, contact_id: int, data: Dict[str, Any]) -> bool:
        """
        Update a connection with notes, tags, or other metadata.
        Only updates the one-way relationship (from user_id to contact_id).
        
        Args:
            user_id: ID of the user
            contact_id: ID of the contact
            data: Dictionary of fields to update (relationship_description, notes, tags)
            
        Returns:
            True if successful, False otherwise
        """
        # Build the SET clause dynamically based on provided fields
        set_fields = []
        params = []
        
        # Handle all updateable fields
        for key, value in data.items():
            if key in ['notes', 'tags', 'relationship_description', 'what_they_are_working_on']:
                set_fields.append(f"{key} = %s")
                params.append(value)
        
        # Always update the last_viewed timestamp
        set_fields.append("last_viewed = NOW()")
        
        # Create the update query
        if not set_fields:
            # If only updating timestamp
            query = """
            UPDATE relationships
            SET last_viewed = NOW()
            WHERE user_id = %s AND contact_id = %s;
            """
            params = [user_id, contact_id]
        else:
            params.extend([user_id, contact_id])
            query = f"""
            UPDATE relationships
            SET {', '.join(set_fields)}
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
        This is a one-way update (only from user_id to contact_id).
        
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

    # ========== USER TAGS ==========
    
    def get_user_recent_tags(self, user_id: int) -> List[str]:
        """
        Get a user's recently used tags.
        
        Args:
            user_id: The ID of the user
            
        Returns:
            List of recent tags or empty list if none found
        """
        query = """
        SELECT recent_tags FROM people
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
        
        # Add new tags first (regardless of whether they're already in current_tags)
        for tag in new_tags:
            if tag and tag not in updated_tags:  # Only check for duplicates within new_tags
                updated_tags.append(tag)
        
        # Then add existing tags (avoiding duplicates)
        for tag in current_tags:
            if tag and tag not in updated_tags:
                updated_tags.append(tag)
        
        # Limit to max_tags
        updated_tags = updated_tags[:max_tags]
        
        # Convert list to comma-separated string
        tags_string = ','.join(updated_tags) if updated_tags else None
        
        # Update the user record
        query = """
        UPDATE people
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
            print(f"Error updating user recent tags: {e}")
            return False

    # ========== LOGIN & AUTHENTICATION ==========
    
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
        INSERT INTO logins (people_id, username, passkey, last_login)
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
        SELECT people_id
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
                
            return result['people_id'] if result else None
        except Exception as e:
            print(f"Error validating login: {e}")
            return None

    def update_passwords(self, new_password: str = "password") -> bool:
        """
        Update all user passwords to a standard value.
        
        Args:
            new_password: The password to set for all users
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Get all users with usernames
            self.cursor.execute("SELECT id, username, first_name, last_name FROM people WHERE username IS NOT NULL;")
            users = self.cursor.fetchall()
            print(f"Found {len(users)} users with usernames")
            
            # Update passwords for users
            password_updates = 0
            for user in users:
                user_id = user['id']
                username = user['username']
                first_name = user['first_name']
                last_name = user['last_name']
                
                # Check if login exists
                self.cursor.execute("SELECT id FROM logins WHERE user_id = %s;", (user_id,))
                login = self.cursor.fetchone()
                
                if login:
                    # Update existing login
                    self.cursor.execute(
                        "UPDATE logins SET passkey = %s WHERE user_id = %s;", 
                        (new_password, user_id)
                    )
                    print(f"Updated password for {first_name} {last_name} (ID: {user_id})")
                else:
                    # Create new login
                    self.cursor.execute(
                        "INSERT INTO logins (people_id, username, passkey) VALUES (%s, %s, %s);",
                        (user_id, username, new_password)
                    )
                    print(f"Created login for {first_name} {last_name} (ID: {user_id})")
                
                password_updates += 1
             
            self.connection.commit()
            print(f"Updated {password_updates} user passwords to '{new_password}'")
            
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"Error updating passwords: {e}")
            return False
    
    # ========== DATABASE UTILITIES ==========
    
    def check_database(self) -> bool:
        """
        Check the current state of the database.
        
        Returns:
            True if check completed successfully
        """
        try:
            # Get users
            self.cursor.execute("SELECT id, username, first_name, last_name FROM people ORDER BY id;")
            users = self.cursor.fetchall()
            print(f"=== Users ({len(users)}) ===")
            for user in users:
                print(f"{user['id']}: {user['first_name']} {user['last_name']} (username: {user['username']})")
            
            # Get logins
            self.cursor.execute("SELECT people_id, username, passkey FROM logins ORDER BY people_id;")
            logins = self.cursor.fetchall()
            print(f"\n=== Logins ({len(logins)}) ===")
            for login in logins:
                print(f"User ID: {login['people_id']}, Username: {login['username']}, Password: {login['passkey']}")
            
            # Get relationships
            self.cursor.execute("""
                SELECT r.user_id, u1.first_name, r.contact_id, u2.first_name, r.relationship_description 
                FROM relationships r
                JOIN people u1 ON r.user_id = u1.id
                JOIN people u2 ON r.contact_id = u2.id
                ORDER BY r.user_id, r.contact_id;
            """)
            relationships = self.cursor.fetchall()
            print(f"\n=== Relationships ({len(relationships)}) ===")
            for rel in relationships:
                print(f"{rel['user_id']} ({rel['first_name']}) -> {rel['contact_id']} ({rel['first_name_1']}): {rel['relationship_description']}")
            
            return True
        except Exception as e:
            print("An error occurred:", e)
            return False
    
    def update_last_login(self, user_id: int) -> bool:
        """
        Update the last_login timestamp for a user.
        
        Args:
            user_id: The ID of the user to update
            
        Returns:
            bool: True if successful, False otherwise
        """
        try:
            query = """
                UPDATE logins 
                SET last_login = NOW() 
                WHERE people_id = %s
            """
            return self.execute_query(query, (user_id,))
        except Exception as e:
            print(f"Error updating last login: {e}")
            return False
            
    def clean_test_data(self, real_user_id_threshold: int = 5) -> bool:
        """
        Remove test data from the database.
        
        Args:
            real_user_id_threshold: IDs above this threshold are considered test users
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Delete test users and their connections
            self.cursor.execute(f"DELETE FROM relationships WHERE user_id > {real_user_id_threshold} OR contact_id > {real_user_id_threshold};")
            deleted_connections = self.cursor.rowcount
            print(f"Deleted {deleted_connections} test connections")
            
            self.cursor.execute(f"DELETE FROM logins WHERE people_id > {real_user_id_threshold};")
            deleted_logins = self.cursor.rowcount
            print(f"Deleted {deleted_logins} test logins")
            
            self.cursor.execute(f"DELETE FROM people WHERE id > {real_user_id_threshold};")
            deleted_users = self.cursor.rowcount
            print(f"Deleted {deleted_users} test users")
            
            # Commit the changes
            self.connection.commit()
            return True
        except Exception as e:
            print("An error occurred:", e)
            self.connection.rollback()
            return False
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit point."""
        self.disconnect()

    def user_has_login(self, user_id: int) -> bool:
        """
        Check if a user has login credentials.
        
        Args:
            user_id: ID of the user to check
            
        Returns:
            True if the user has login credentials, False otherwise
        """
        query = """
        SELECT COUNT(*) AS login_count
        FROM logins
        WHERE people_id = %s;
        """
        
        try:
            self.cursor.execute(query, (user_id,))
            result = self.cursor.fetchone()
            
            # If login count is greater than 0, user has login credentials
            return result and result['login_count'] > 0
        except Exception as e:
            print(f"Error checking if user has login: {e}")
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
            print(f"Interests: {user['interests']}")
            
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
            "interests": "Artificial Intelligence, Robotics",
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