"""
Insert sample relationships between users in the Nexus database.

This module provides a function to create sample relationships between users,
demonstrating the various types of connections that can be established in the application.
The relationships include different relationship types, notes, and tags.
"""

import psycopg2
import datetime
import random
import os
import sys

# Add parent directory to the path so we can import from the parent directory
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
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
            # Connection to Soren
            soren_id = user_ids.get('soren')
            if soren_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': soren_id,
                    'description': "College friends",
                    'custom_note': "Met at CMU during freshman orientation. Works on math research projects. Good contact for academic collaborations.",
                    'tags': "college,math,research,academic",
                    'last_viewed': datetime.datetime.now()
                })
            
            # Connection to Max
            max_id = user_ids.get('max')
            if max_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': max_id,
                    'description': "College roommate",
                    'custom_note': "Shared apartment during sophomore year. Has good business connections in New Jersey.",
                    'tags': "college,roommate,business,new jersey",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=2)
                })
            
            # Connection to Stan
            stan_id = user_ids.get('stan')
            if stan_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': stan_id,
                    'description': "CS study group",
                    'custom_note': "Great programmer with expertise in algorithms. Now works in London, good international contact.",
                    'tags': "CS,algorithms,international,london",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=5)
                })
            
            # Connection to Corwin
            corwin_id = user_ids.get('corwin')
            if corwin_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': corwin_id,
                    'description': "High school friend",
                    'custom_note': "Entrepreneur with multiple startups. Good contact for investment opportunities.",
                    'tags': "high school,entrepreneur,investing,startups",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=1)
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
                'description': "College friends",
                'custom_note': "Met through Daniel at a campus event. Good at explaining complex economics concepts.",
                'tags': "college,economics,academic",
                'last_viewed': datetime.datetime.now() - datetime.timedelta(days=7)
            })
        else:
            print(f"Warning: Max or Soren not found in the database. Max ID: {max_id}, Soren ID: {soren_id}")
        
        # Insert the relationships
        relationship_sql = """
        INSERT INTO relationships (
            user_id, contact_id, relationship_description, 
            custom_note, tags, last_viewed
        )
        VALUES (
            %(user_id)s, %(contact_id)s, %(description)s,
            %(custom_note)s, %(tags)s, %(last_viewed)s
        );
        """
        
        # First clear any existing relationships
        cursor.execute("DELETE FROM relationships;")
        print("Cleared existing relationships")
        
        for rel in relationships:
            # Insert in one direction
            cursor.execute(relationship_sql, rel)
            
            # Create the reverse direction data
            reverse_rel = {
                'user_id': rel['contact_id'],
                'contact_id': rel['user_id'],
                'description': rel['description'],
                'custom_note': rel['custom_note'],
                'tags': rel['tags'],
                'last_viewed': rel['last_viewed'] - datetime.timedelta(days=random.randint(1, 3))
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