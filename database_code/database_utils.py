import psycopg2
from config import DATABASE_URL
from typing import Dict, List, Any, Tuple, Optional
import psycopg2.extras

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
            cursor.execute("SELECT id, username, first_name, last_name FROM people ORDER BY id;")
            users = cursor.fetchall()
            print(f"=== Users ({len(users)}) ===")
            for user_id, username, first_name, last_name in users:
                print(f"{user_id}: {first_name} {last_name} (username: {username})")
            
            # Get logins
            cursor.execute("SELECT people_id, username, passkey FROM logins ORDER BY people_id;")
            logins = cursor.fetchall()
            print(f"\n=== Logins ({len(logins)}) ===")
            for login in logins:
                print(f"User ID: {login[0]}, Username: {login[1]}, Password: {login[2]}")
            
            # Get relationships
            cursor.execute("""
                SELECT r.user_id, u1.first_name, r.contact_id, u2.first_name, r.relationship_description 
                FROM relationships r
                JOIN people u1 ON r.user_id = u1.id
                JOIN people u2 ON r.contact_id = u2.id
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
    def update_passwords(cls, default_password="password"):
        """
        Set a default password for all users and update the login table.
        
        Args:
            default_password: The default password to set for all users
            
        Returns:
            Number of users updated
        """
        conn = None
        cur = None
        try:
            # Connect to database
            conn = psycopg2.connect(DATABASE_URL)
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            
            # Get all users who have non-null recent_tags and don't have login credentials
            query = """
            SELECT u.id, u.first_name, u.last_name
            FROM people u
            LEFT JOIN logins l ON u.id = l.people_id
            WHERE l.id IS NULL AND u.recent_tags IS NOT NULL;
            """
            
            cur.execute(query)
            users = cur.fetchall()
            
            # Add default login credentials for these users
            count = 0
            for user in users:
                user_id = user['id']
                first_name = user['first_name']
                last_name = user['last_name']
                
                # Create a username from the first and last name (lowercase, no spaces)
                username = (first_name + last_name).lower().replace(' ', '')
                
                # Add the login
                insert_query = """
                INSERT INTO logins (people_id, username, passkey, last_login)
                VALUES (%s, %s, %s, NOW());
                """
                
                cur.execute(insert_query, (user_id, username, default_password))
                count += 1
            
            conn.commit()
            print(f"Added login credentials for {count} users with password '{default_password}'")
            
            return count
        except Exception as e:
            if conn:
                conn.rollback()
            raise e
        finally:
            if cur:
                cur.close()
            if conn:
                conn.close()
    
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
            
            cursor.execute(f"DELETE FROM logins WHERE people_id > {real_user_id_threshold};")
            deleted_logins = cursor.rowcount
            print(f"Deleted {deleted_logins} test logins")
            
            cursor.execute(f"DELETE FROM people WHERE id > {real_user_id_threshold};")
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
                "UPDATE people SET username = %s WHERE id = %s AND (username IS NULL OR username != %s);", 
                (username, user_id, username)
            )
            
            # Check if login exists
            cursor.execute("SELECT id FROM logins WHERE people_id = %s;", (user_id,))
            login = cursor.fetchone()
                
            if login:
                # Update existing login
                cursor.execute(
                    "UPDATE logins SET passkey = %s WHERE people_id = %s;", 
                    (password, user_id)
                )
            else:
                # Create new login
                cursor.execute(
                    "INSERT INTO logins (people_id, username, passkey) VALUES (%s, %s, %s);",
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