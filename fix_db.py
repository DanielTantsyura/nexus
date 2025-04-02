import psycopg2
import psycopg2.extras
import sys
import time

# Simple script to validate DB connection and fix common issues
try:
    connection_string = "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"
    print("Connecting to database...")
    conn = psycopg2.connect(
        connection_string,
        connect_timeout=10,
        keepalives=1,
        keepalives_idle=60
    )
    conn.autocommit = False
    print("Connection successful!")
    
    # Create a cursor
    cursor = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    
    # Test a simple query
    print("Testing query...")
    cursor.execute("SELECT COUNT(*) FROM users")
    result = cursor.fetchone()
    print(f"User count: {result[0]}")
    
    # Test specific user
    cursor.execute("SELECT * FROM users WHERE id = 1")
    user = cursor.fetchone()
    if user:
        print(f"Found user with ID 1: {user['first_name']} {user['last_name']}")
        user_id = user['id']
        username = user['username']
    else:
        print("User with ID 1 not found in database")
        sys.exit(1)
    
    # Check login table
    print("\nChecking logins table...")
    cursor.execute("SELECT * FROM logins WHERE user_id = %s", (user_id,))
    login = cursor.fetchone()
    if login:
        print(f"Found login for user {user_id}")
    else:
        print(f"No login found for user {user_id}. Creating one...")
        cursor.execute(
            "INSERT INTO logins (user_id, username, passkey, last_login) VALUES (%s, %s, %s, NOW())",
            (user_id, username, "password")
        )
        conn.commit()
        print(f"Created login for user {user_id}")
    
    # Test update_last_login
    print("\nTesting update_last_login...")
    cursor.execute(
        "UPDATE logins SET last_login = NOW() WHERE user_id = %s RETURNING last_login",
        (user_id,)
    )
    result = cursor.fetchone()
    if result:
        print(f"Updated last_login to {result['last_login']}")
        conn.commit()
    else:
        print("Failed to update last_login")
    
    # Test connection retrieval
    print("\nTesting connection retrieval...")
    cursor.execute("""
        SELECT 
            u.id, u.first_name, u.last_name
        FROM relationships r
        JOIN users u ON r.contact_id = u.id
        WHERE r.user_id = %s
        ORDER BY u.first_name, u.last_name
    """, (user_id,))
    connections = cursor.fetchall()
    print(f"Found {len(connections)} connections for user {user_id}")
    for conn_user in connections:
        print(f"  - {conn_user['first_name']} {conn_user['last_name']}")
    
    # Close cursor and connection
    cursor.close()
    conn.close()
    print("\nTest complete - database connection is working properly!")
    sys.exit(0)
except Exception as e:
    print(f"Error: {str(e)}")
    sys.exit(1) 