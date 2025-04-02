"""
Test the creation of a new contact with additional notes extraction.
"""

import os
import sys
from dotenv import load_dotenv
import requests

# Add the parent directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database_code.newUser import process_contact_text
from database_code.database_operations import DatabaseManager
from config import DEFAULT_TAGS, API_PORT

# Load environment variables
load_dotenv()

# Construct API base URL
API_BASE_URL = f"http://localhost:{API_PORT}"

def create_test_contact(text, tags, current_user_id):
    """
    A test version of create_new_contact that uses the API endpoints.
    
    Args:
        text: Free-form text containing user information
        tags: List of tags to apply to the relationship
        current_user_id: ID of the current user
        
    Returns:
        Tuple containing:
        - Success flag (bool)
        - Message string (success or error message)
        - User ID of the new contact (or None if failed)
    """
    # Process the text into structured user data and additional notes
    success, user_data, message, additional_notes = process_contact_text(text, tags, current_user_id)
    
    if not success:
        return False, message, None
    
    # Convert tags list to comma-separated string for the database
    tags_string = ",".join(tags) if tags else None
    
    # Create the new user
    try:
        # API endpoint for adding a new user
        user_endpoint = f"{API_BASE_URL}/users"
        user_response = requests.post(user_endpoint, json=user_data)
        
        if user_response.status_code != 201:
            error_msg = user_response.json().get("error", "Unknown error")
            return False, f"Failed to create user: {error_msg}", None
        
        # Get the ID of the newly created user
        new_user_id = user_response.json().get("id")
        
        # Prepare note text, combining the original text and any additional notes
        note_text = f"Created from text: {text[:100]}..."
        if additional_notes:
            note_text += f"\n\nAdditional notes: {additional_notes}"
        
        # Create a connection between the current user and the new user
        connection_endpoint = f"{API_BASE_URL}/connections"
        connection_data = {
            "user_id": current_user_id,
            "contact_id": new_user_id,
            "relationship_type": "Contact",  # Default relationship type
            "note": note_text,  # Include both original text and additional notes
            "tags": tags_string
        }
        
        connection_response = requests.post(connection_endpoint, json=connection_data)
        
        if connection_response.status_code != 201:
            error_msg = connection_response.json().get("error", "Unknown error")
            return False, f"User created but failed to establish connection: {error_msg}", new_user_id
        
        return True, "Contact successfully created and connected", new_user_id
        
    except Exception as e:
        return False, f"Error creating contact: {str(e)}", None

def test_create_contact_with_notes():
    """Test creating a contact that includes additional notes."""
    
    # Use a sample text with information that should be extracted as additional notes
    contact_text = """
    Jane Smith is a software architect at Amazon. She specializes in cloud infrastructure 
    and distributed systems. We met at the Cloud Computing Summit in Seattle last month
    where she gave a talk on serverless architectures. She mentioned she's looking for 
    collaborators on an open-source project related to Kubernetes. She has twin daughters
    and enjoys rock climbing on weekends. She recommended "Designing Data-Intensive Applications"
    as a must-read book.
    """
    
    # Sample tags for the relationship
    tags = ["tech", "cloud", "networking"]
    
    # Use ID 1 (presumably Daniel's ID in the test database)
    current_user_id = 1
    
    print("\n=== Testing Contact Creation with Notes ===\n")
    print(f"Creating contact with text:\n{contact_text.strip()}\n")
    print(f"Tags: {tags}")
    print(f"Current user ID: {current_user_id}\n")
    
    # Create the contact using our function with the correct port
    success, message, new_user_id = create_test_contact(contact_text, tags, current_user_id)
    
    # Print the result
    if success:
        print("✅ Successfully created contact")
        print(f"Message: {message}")
        print(f"New user ID: {new_user_id}")
        
        # Fetch the relationship to verify the notes were added correctly
        db = DatabaseManager()
        db.connect()
        try:
            # Get the connections for the user
            connections = db.get_user_connections(current_user_id)
            # Find the connection to the new user
            connection = next((c for c in connections if c['id'] == new_user_id), None)
            
            if connection:
                print("\n✅ Retrieved relationship from database")
                print(f"Relationship type: {connection['relationship_type']}")
                print(f"Note: {connection['note']}")
                print(f"Tags: {connection['tags']}")
            else:
                print("\n❌ Could not find relationship in database")
        finally:
            db.disconnect()
        
    else:
        print("❌ Failed to create contact")
        print(f"Error message: {message}")

if __name__ == "__main__":
    test_create_contact_with_notes() 