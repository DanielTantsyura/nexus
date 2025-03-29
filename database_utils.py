import psycopg2
from config import DATABASE_URL
from typing import Dict, List, Any, Tuple, Optional

class DatabaseUtils:
    """
    Utility class for database management operations including:
    - Checking database state
    - Updating passwords
    - Inserting sample logins
    - Managing user credentials
    - Cleaning test data
    """
    
    @staticmethod
    def execute_query(query: str, params: Optional[Tuple] = None, fetch: bool = False, 
                     commit: bool = False, fetch_all: bool = False):
        """
        Execute a database query with error handling.
        
        Args:
            query: SQL query to execute
            params: Query parameters (optional)
            fetch: Whether to fetch a single result
            commit: Whether to commit the transaction
            fetch_all: Whether to fetch all results
            
        Returns:
            Query results or None on error
        """
        conn = None
        try:
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            
            result = None
            if fetch:
                result = cursor.fetchone()
            elif fetch_all:
                result = cursor.fetchall()
            
            if commit:
                conn.commit()
                
            rowcount = cursor.rowcount
            
            cursor.close()
            conn.close()
            
            return result if fetch or fetch_all else rowcount
        except Exception as e:
            print(f"Database error: {e}")
            if conn and commit:
                conn.rollback()
            return None
        finally:
            if conn:
                conn.close()
    
    @classmethod
    def check_database(cls) -> bool:
        """
        Check the current state of the database.
        
        Returns:
            True if check completed successfully
        """
        try:
            # Connect to the database
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # Get users
            cursor.execute("SELECT id, username, first_name, last_name FROM users ORDER BY id;")
            users = cursor.fetchall()
            print(f"=== Users ({len(users)}) ===")
            for user_id, username, first_name, last_name in users:
                print(f"{user_id}: {first_name} {last_name} (username: {username})")
            
            # Get logins
            cursor.execute("SELECT user_id, username, passkey FROM logins ORDER BY user_id;")
            logins = cursor.fetchall()
            print(f"\n=== Logins ({len(logins)}) ===")
            for user_id, username, passkey in logins:
                print(f"User ID: {user_id}, Username: {username}, Password: {passkey}")
            
            # Get relationships
            cursor.execute("""
                SELECT r.user_id, u1.first_name, r.contact_id, u2.first_name, r.relationship_description 
                FROM relationships r
                JOIN users u1 ON r.user_id = u1.id
                JOIN users u2 ON r.contact_id = u2.id
                ORDER BY r.user_id, r.contact_id;
            """)
            relationships = cursor.fetchall()
            print(f"\n=== Relationships ({len(relationships)}) ===")
            for user_id, user_name, contact_id, contact_name, description in relationships:
                print(f"{user_id} ({user_name}) -> {contact_id} ({contact_name}): {description}")
            
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            print("An error occurred:", e)
            return False
    
    @classmethod
    def update_passwords(cls, new_password: str = "password") -> bool:
        """
        Update all user passwords to a standard value.
        
        Args:
            new_password: The password to set for all users
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to the database
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # Get all users with usernames
            cursor.execute("SELECT id, username, first_name, last_name FROM users WHERE username IS NOT NULL;")
            users = cursor.fetchall()
            print(f"Found {len(users)} users with usernames")
            
            # Update passwords for users
            password_updates = 0
            for user_id, username, first_name, last_name in users:
                # Check if login exists
                cursor.execute("SELECT id FROM logins WHERE user_id = %s;", (user_id,))
                login = cursor.fetchone()
                
                if login:
                    # Update existing login
                    cursor.execute(
                        "UPDATE logins SET passkey = %s WHERE user_id = %s;", 
                        (new_password, user_id)
                    )
                    print(f"Updated password for {first_name} {last_name} (ID: {user_id})")
                else:
                    # Create new login
                    cursor.execute(
                        "INSERT INTO logins (user_id, username, passkey) VALUES (%s, %s, %s);",
                        (user_id, username, new_password)
                    )
                    print(f"Created login for {first_name} {last_name} (ID: {user_id})")
                
                password_updates += 1
            
            conn.commit()
            print(f"Updated {password_updates} user passwords to '{new_password}'")
            
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            print("An error occurred:", e)
            if conn:
                conn.rollback()
            return False
    
    @classmethod
    def clean_test_data(cls, real_user_id_threshold: int = 5) -> bool:
        """
        Remove test data from the database.
        
        Args:
            real_user_id_threshold: IDs above this threshold are considered test users
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to the database
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # Delete test users and their connections
            cursor.execute(f"DELETE FROM relationships WHERE user_id > {real_user_id_threshold} OR contact_id > {real_user_id_threshold};")
            deleted_connections = cursor.rowcount
            print(f"Deleted {deleted_connections} test connections")
            
            cursor.execute(f"DELETE FROM logins WHERE user_id > {real_user_id_threshold};")
            deleted_logins = cursor.rowcount
            print(f"Deleted {deleted_logins} test logins")
            
            cursor.execute(f"DELETE FROM users WHERE id > {real_user_id_threshold};")
            deleted_users = cursor.rowcount
            print(f"Deleted {deleted_users} test users")
            
            # Commit the changes
            conn.commit()
            
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            print("An error occurred:", e)
            if conn:
                conn.rollback()
            return False
    
    @classmethod
    def ensure_user_login(cls, user_id: int, username: str, password: str) -> bool:
        """
        Ensure a specific user has login credentials.
        
        Args:
            user_id: The user ID
            username: The username
            password: The password
            
        Returns:
            True if successful, False otherwise
        """
        try:
            # Connect to the database
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # First update username if needed
            cursor.execute(
                "UPDATE users SET username = %s WHERE id = %s AND (username IS NULL OR username != %s);", 
                (username, user_id, username)
            )
            
            # Check if login exists
            cursor.execute("SELECT id FROM logins WHERE user_id = %s;", (user_id,))
            login = cursor.fetchone()
                
            if login:
                # Update existing login
                cursor.execute(
                    "UPDATE logins SET passkey = %s WHERE user_id = %s;", 
                    (password, user_id)
                )
            else:
                # Create new login
                cursor.execute(
                    "INSERT INTO logins (user_id, username, passkey) VALUES (%s, %s, %s);",
                    (user_id, username, password)
                )
            
            conn.commit()
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            print(f"Error ensuring login for user {user_id}: {e}")
            if conn:
                conn.rollback()
            return False

# Command-line interface
if __name__ == "__main__":
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python database_utils.py [check|passwords|clean|login] [args]")
        sys.exit(1)
        
    command = sys.argv[1].lower()
    
    if command == "check":
        DatabaseUtils.check_database()
    elif command == "passwords":
        password = "password" if len(sys.argv) < 3 else sys.argv[2]
        DatabaseUtils.update_passwords(password)
    elif command == "clean":
        threshold = 5 if len(sys.argv) < 3 else int(sys.argv[2])
        DatabaseUtils.clean_test_data(threshold)
    elif command == "login":
        if len(sys.argv) < 5:
            print("Usage: python database_utils.py login <user_id> <username> <password>")
            sys.exit(1)
        DatabaseUtils.ensure_user_login(int(sys.argv[2]), sys.argv[3], sys.argv[4])
    else:
        print(f"Unknown command: {command}")
        print("Available commands: check, passwords, clean, login")
        sys.exit(1) 