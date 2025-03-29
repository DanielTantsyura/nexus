import psycopg2
from config import DATABASE_URL

def check_database():
    """Check the current state of the database."""
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

if __name__ == "__main__":
    check_database() 