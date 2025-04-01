"""
Module for processing free-form text into structured user data and creating new users.
This will eventually use an LLM for processing the text input.
"""

import json
import requests
from typing import Dict, List, Tuple, Optional

def process_contact_text(text: str, tags: List[str], current_user_id: int) -> Tuple[bool, Optional[Dict], str]:
    """
    Process free-form text into a structured user object using NLP/LLM techniques.
    In the future, this will use an LLM to extract structured information.
    
    Args:
        text: Free-form text input containing user information
        tags: List of tags to apply to the relationship
        current_user_id: ID of the currently logged-in user
    
    Returns:
        Tuple containing:
        - Success flag (bool)
        - User data dictionary (Dict) or None if processing failed
        - Message string (success or error message)
    """
    # Basic validation - for now just check if there's content
    if not text or len(text.strip()) < 5:
        return False, None, "Not enough information provided. Please provide more details."
    
    # TEMPORARY IMPLEMENTATION
    # In the future, this will use an LLM to extract structured information
    # For now, we'll just create a basic implementation that extracts the first two words as name
    
    words = text.strip().split()
    if len(words) < 2:
        return False, None, "At least first and last name are required."
    
    # Extract first and last name (minimum required fields)
    first_name = words[0]
    last_name = words[1]
    
    # Create a basic user object with the required fields
    user_data = {
        "first_name": first_name,
        "last_name": last_name,
        # Set other fields to None for now
        "username": None,
        "email": None,
        "phone_number": None,
        "location": None,
        "university": None,
        "field_of_interest": None,
        "high_school": None,
        "gender": None,
        "ethnicity": None,
        "uni_major": None,
        "job_title": None,
        "current_company": None,
        "profile_image_url": None,
        "linkedin_url": None
    }
    
    return True, user_data, "Successfully processed contact information."

def create_new_contact(text: str, tags: List[str], current_user_id: int) -> Tuple[bool, str, Optional[int]]:
    """
    Create a new contact from free-form text and establish a relationship with the current user.
    
    Args:
        text: Free-form text input containing user information
        tags: List of tags to apply to the relationship
        current_user_id: ID of the currently logged-in user
    
    Returns:
        Tuple containing:
        - Success flag (bool)
        - Message string (success or error message)
        - New user ID (int) or None if creation failed
    """
    # Process the text input
    success, user_data, message = process_contact_text(text, tags, current_user_id)
    if not success:
        return False, message, None
    
    try:
        # Call the API to create the user
        api_url = "http://127.0.0.1:8080/users"  # Assuming API is running locally
        response = requests.post(api_url, json=user_data)
        
        if response.status_code != 201:
            return False, f"Failed to create user: {response.json().get('error', 'Unknown error')}", None
        
        # Get the new user ID
        new_user_id = response.json().get('id')
        
        # Create a relationship between the current user and the new user
        if tags:
            tags_str = ",".join(tags)
        else:
            tags_str = ""
            
        relationship_data = {
            "user_id": current_user_id,
            "contact_id": new_user_id,
            "description": "Added via contact form",
            "custom_note": text,  # Store the original text as a note
            "tags": tags_str
        }
        
        # Call the API to create the relationship
        relationship_url = "http://127.0.0.1:8080/connections"
        rel_response = requests.post(relationship_url, json=relationship_data)
        
        if rel_response.status_code != 201:
            return False, f"User created but failed to establish relationship: {rel_response.json().get('error', 'Unknown error')}", new_user_id
        
        return True, "Contact successfully created and added to your connections.", new_user_id
        
    except Exception as e:
        return False, f"An error occurred: {str(e)}", None

if __name__ == "__main__":
    # Test the function with sample data
    sample_text = "John Doe john.doe@example.com 123-456-7890 Harvard University"
    sample_tags = ["friend", "harvard", "tech"]
    sample_user_id = 1
    
    success, message, user_id = create_new_contact(sample_text, sample_tags, sample_user_id)
    print(f"Success: {success}")
    print(f"Message: {message}")
    print(f"User ID: {user_id}") 