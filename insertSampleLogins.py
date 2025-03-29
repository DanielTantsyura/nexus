import psycopg2
from config import DATABASE_URL

def insert_sample_logins():
    """Insert sample login credentials for existing users."""
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # First, query to get the user IDs and usernames
        get_users_sql = "SELECT id, username, first_name, last_name FROM users WHERE username IS NOT NULL;"
        cursor.execute(get_users_sql)
        
        users = cursor.fetchall()
        print(f"Found {len(users)} users with usernames in the database")
        
        # Clear any existing logins
        cursor.execute("DELETE FROM logins;")
        print("Cleared existing login credentials")
        
        # Insert login for each user
        login_sql = """
        INSERT INTO logins (user_id, username, passkey)
        VALUES (%s, %s, %s);
        """
        
        login_count = 0
        for user_id, username, first_name, last_name in users:
            if username:
                # Create a simple passkey based on name
                passkey = f"{first_name.lower()}{last_name.lower()}123"
                
                cursor.execute(login_sql, (user_id, username, passkey))
                login_count += 1
                print(f"Added login for {first_name} {last_name} (username: {username}, passkey: {passkey})")
        
        conn.commit()
        print(f"{login_count} login credentials added successfully.")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        return False

if __name__ == "__main__":
    insert_sample_logins() 