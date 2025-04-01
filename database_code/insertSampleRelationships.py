"""
Insert sample relationships between users in the Nexus database.

This module provides a function to create sample relationships between users,
demonstrating the various types of connections that can be established in the application.
The relationships include different relationship types, notes, and tags.
"""

import json
from typing import List, Dict, Any, Optional
from database_operations import DatabaseManager
from config import DATABASE_URL

def insert_sample_relationships(users: Optional[List[Dict[str, Any]]] = None) -> bool:
    """
    Insert sample relationships between users in the database.
    
    Args:
        users: List of user dictionaries (optional). If not provided, 
               it uses previously inserted users from the database.
    
    Returns:
        True if successful, False otherwise
    """
    try:
        with DatabaseManager(DATABASE_URL) as db:
            # If users are not provided, get them from the database
            if not users:
                print("No users provided, fetching users from the database...")
                all_users = db.get_all_users()
                if not all_users or len(all_users) < 2:
                    print("Not enough users in the database to create relationships")
                    return False
            else:
                # Fetch the user IDs for the provided users
                all_users = []
                for user in users:
                    db_user = db.get_user_by_username(user["username"])
                    if db_user:
                        all_users.append(db_user)
            
            print(f"Found {len(all_users)} users for creating relationships")
            
            # Create a dictionary mapping usernames to user IDs for easy lookup
            user_dict = {user['username']: user['id'] for user in all_users if user['username']}
            
            # Define the relationships to create
            relationships = [
                # User 1 relationships
                {
                    "user": user_dict.get(all_users[0]['username']),
                    "contact": user_dict.get(all_users[1]['username']),
                    "relationship_type": "Friend",
                    "note": "Met at university. Interested in technology and entrepreneurship.",
                    "tags": "friend,classmate,tech"
                },
                {
                    "user": user_dict.get(all_users[0]['username']),
                    "contact": user_dict.get(all_users[2]['username']),
                    "relationship_type": "Colleague",
                    "note": "Works in the same company. Expert in data science.",
                    "tags": "work,data science,mentor"
                },
                
                # User 2 relationships
                {
                    "user": user_dict.get(all_users[1]['username']),
                    "contact": user_dict.get(all_users[3]['username']),
                    "relationship_type": "Business Contact",
                    "note": "Met at industry conference. Potential partnership opportunity.",
                    "tags": "business,conference,opportunity"
                },
                
                # User 3 relationships
                {
                    "user": user_dict.get(all_users[2]['username']),
                    "contact": user_dict.get(all_users[4]['username']),
                    "relationship_type": "Networking",
                    "note": "Introduced by a mutual friend. Works in the finance sector.",
                    "tags": "finance,networking,introduction"
                },
                
                # Additional connections to create a more complex network
                {
                    "user": user_dict.get(all_users[0]['username']),
                    "contact": user_dict.get(all_users[4]['username']),
                    "relationship_type": "Friend",
                    "note": "Old college buddy. Keep in touch for social events.",
                    "tags": "friend,social,alumni"
                },
                {
                    "user": user_dict.get(all_users[3]['username']),
                    "contact": user_dict.get(all_users[1]['username']),
                    "relationship_type": "Mentor",
                    "note": "Provides career advice and industry insights.",
                    "tags": "mentor,career,guidance"
                }
            ]
            
            # Filter out relationships with missing user IDs
            valid_relationships = [r for r in relationships 
                                  if r["user"] is not None and r["contact"] is not None]
            
            if not valid_relationships:
                print("No valid relationships to create")
                return False
                
            # Create the relationships
            success_count = 0
            for rel in valid_relationships:
                success = db.add_connection(
                    user_id=rel["user"],
                    contact_id=rel["contact"],
                    relationship_type=rel["relationship_type"],
                    note=rel["note"],
                    tags=rel["tags"]
                )
                
                if success:
                    success_count += 1
                    print(f"Created relationship: {rel['relationship_type']} between User ID {rel['user']} and Contact ID {rel['contact']}")
            
            print(f"Created {success_count} out of {len(valid_relationships)} relationships")
            return success_count > 0
            
    except Exception as e:
        print(f"Error inserting sample relationships: {e}")
        return False

if __name__ == "__main__":
    # When run directly, insert sample relationships
    success = insert_sample_relationships()
    if success:
        print("Successfully inserted sample relationships")
    else:
        print("Failed to insert sample relationships") 