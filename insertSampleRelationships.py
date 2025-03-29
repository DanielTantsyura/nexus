import psycopg2
from config import DATABASE_URL

def insert_sample_relationships():
    """Insert sample relationships between users in the database."""
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # First, query to get the user IDs by name
        get_user_id_sql = "SELECT id, first_name FROM users;"
        cursor.execute(get_user_id_sql)
        
        user_ids = {}
        for id, first_name in cursor.fetchall():
            user_ids[first_name.lower()] = id
        
        print(f"Found {len(user_ids)} users in the database")
        
        # Define the relationships to add - no longer need to define both directions
        # since the add_connection function now handles bidirectional connections
        relationships = []
        
        # Add Daniel's connections to everyone
        daniel_id = user_ids.get('daniel')
        if daniel_id:
            for name, id in user_ids.items():
                if name != 'daniel':  # Skip self-connection
                    relationships.append({
                        'user_id': daniel_id,
                        'contact_id': id,
                        'description': f"Friends and colleagues"
                    })
        else:
            print("Warning: Daniel not found in the database")
        
        # Add Max-Soren connection - only need to define one direction
        max_id = user_ids.get('max')
        soren_id = user_ids.get('soren')
        if max_id and soren_id:
            relationships.append({
                'user_id': max_id,
                'contact_id': soren_id,
                'description': "College friends"
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
            # Insert in one direction
            cursor.execute(relationship_sql, rel)
            
            # Insert the reverse direction with the same description
            reverse_rel = {
                'user_id': rel['contact_id'],
                'contact_id': rel['user_id'],
                'description': rel['description']
            }
            cursor.execute(relationship_sql, reverse_rel)
        
        conn.commit()
        print(f"{len(relationships) * 2} relationships added successfully (bidirectional).")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        return False

if __name__ == "__main__":
    insert_sample_relationships() 