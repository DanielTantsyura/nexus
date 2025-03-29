import psycopg2
from config import DATABASE_URL

def update_passwords_and_clean_database():
    """Update all real user passwords to 'password' and remove test users."""
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # First get the original sample user IDs (1-5)
        cursor.execute("SELECT id, username, first_name, last_name FROM users WHERE id <= 5 ORDER BY id;")
        real_users = cursor.fetchall()
        print(f"Found {len(real_users)} real users")
        
        # Update passwords for real users
        password_updates = 0
        for user_id, username, first_name, last_name in real_users:
            if username:
                # Check if login exists
                cursor.execute("SELECT id FROM logins WHERE user_id = %s;", (user_id,))
                login = cursor.fetchone()
                
                if login:
                    # Update existing login
                    cursor.execute(
                        "UPDATE logins SET passkey = %s WHERE user_id = %s;", 
                        ("password", user_id)
                    )
                    print(f"Updated password for {first_name} {last_name} (ID: {user_id})")
                else:
                    # Create new login
                    cursor.execute(
                        "INSERT INTO logins (user_id, username, passkey) VALUES (%s, %s, %s);",
                        (user_id, username, "password")
                    )
                    print(f"Created login for {first_name} {last_name} (ID: {user_id})")
                
                password_updates += 1
        
        # Delete test users and their connections
        cursor.execute("DELETE FROM relationships WHERE user_id > 5 OR contact_id > 5;")
        deleted_connections = cursor.rowcount
        print(f"Deleted {deleted_connections} test connections")
        
        cursor.execute("DELETE FROM logins WHERE user_id > 5;")
        deleted_logins = cursor.rowcount
        print(f"Deleted {deleted_logins} test logins")
        
        cursor.execute("DELETE FROM users WHERE id > 5;")
        deleted_users = cursor.rowcount
        print(f"Deleted {deleted_users} test users")
        
        # Commit the changes
        conn.commit()
        print(f"\nSummary:")
        print(f"- Updated {password_updates} user passwords to 'password'")
        print(f"- Removed {deleted_users} test users")
        print(f"- Removed {deleted_connections} test connections")
        print(f"- Removed {deleted_logins} test logins")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        if conn:
            conn.rollback()
        return False

if __name__ == "__main__":
    update_passwords_and_clean_database() 