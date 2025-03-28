import psycopg2

# Your Railway connection string
conn_str = "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"

try:
    # Connect to the Railway Postgres instance
    conn = psycopg2.connect(conn_str)
    cursor = conn.cursor()
    
    # First, query to get the user IDs by name
    get_user_id_sql = "SELECT id, first_name FROM users;"
    cursor.execute(get_user_id_sql)
    
    user_ids = {}
    for id, first_name in cursor.fetchall():
        user_ids[first_name.lower()] = id
    
    print(f"Found {len(user_ids)} users in the database")
    
    # Define the relationships to add
    # daniel-everyone, max-soren
    relationships = []
    
    # Add Daniel's connections to everyone
    daniel_id = user_ids.get('daniel')
    if daniel_id:
        for name, id in user_ids.items():
            if name != 'daniel':  # Skip self-connection
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': id,
                    'description': f"Daniel knows {name.capitalize()}"
                })
    else:
        print("Warning: Daniel not found in the database")
    
    # Add Max-Soren connection
    max_id = user_ids.get('max')
    soren_id = user_ids.get('soren')
    if max_id and soren_id:
        relationships.append({
            'user_id': max_id,
            'contact_id': soren_id,
            'description': "Max knows Soren"
        })
    else:
        print(f"Warning: Max or Soren not found in the database. Max ID: {max_id}, Soren ID: {soren_id}")
    
    # Insert the relationships
    relationship_sql = """
    INSERT INTO relationships (user_id, contact_id, relationship_description)
    VALUES (%(user_id)s, %(contact_id)s, %(description)s);
    """
    
    # First clear any existing relationships
    cursor.execute("DELETE FROM relationships;")
    print("Cleared existing relationships")
    
    for rel in relationships:
        cursor.execute(relationship_sql, rel)
    
    conn.commit()
    print(f"{len(relationships)} relationships added successfully.")

    cursor.close()
    conn.close()
except Exception as e:
    print("An error occurred:", e) 