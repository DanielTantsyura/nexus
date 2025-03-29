import psycopg2
from config import DATABASE_URL

def add_max_login():
    """Add a login for Max Battaglia (user ID 3)."""
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # First update Max to have a username
        cursor.execute(
            "UPDATE users SET username = %s WHERE id = 3;", 
            ("maxbattaglia",)
        )
        print("Updated Max's username to 'maxbattaglia'")
        
        # Create login for Max
        cursor.execute(
            "INSERT INTO logins (user_id, username, passkey) VALUES (%s, %s, %s);",
            (3, "maxbattaglia", "password")
        )
        print("Created login for Max with password 'password'")
        
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

if __name__ == "__main__":
    add_max_login()