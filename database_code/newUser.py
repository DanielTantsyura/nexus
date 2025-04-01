"""
Module for processing free-form text into structured user data and creating new users.

This module uses the OpenAI API to extract structured information from
unstructured text descriptions, and provides functions to:
- Process contact text into user fields
- Create new users from contact information
- Establish relationships between users
"""

import json
import requests
import os
import re
import time
from typing import Dict, Any, List, Tuple, Optional
import openai
from dotenv import load_dotenv
from config import DATABASE_URL, API_PORT, DEFAULT_TAGS

# Load environment variables
load_dotenv()

# Initialize OpenAI with API key
openai.api_key = os.getenv("OPENAI_API_KEY")

# API endpoints
API_BASE_URL = f"http://localhost:{API_PORT}"

def get_user_fields_from_schema() -> List[str]:
    """
    Get user fields dynamically from the database schema.
    
    Returns:
        List of user field names
    """
    try:
        # Read the createDatabase.py file to extract user fields
        with open("createDatabase.py", "r") as f:
            content = f.read()
            
        # Find the CREATE TABLE statement for users
        match = re.search(r"CREATE TABLE users\s*\((.*?)\);", content, re.DOTALL)
        if match:
            create_table = match.group(1)
            
            # Extract field names
            fields = []
            for line in create_table.split("\n"):
                line = line.strip()
                if line and not line.startswith(("PRIMARY KEY", "CONSTRAINT", "--")):
                    field_name = line.split()[0].strip()
                    if field_name != "id":  # Skip ID field
                        fields.append(field_name)
            
            print(f"Extracted {len(fields)} fields from database schema")
            return fields
        else:
            print("Could not find CREATE TABLE statement for users")
            raise ValueError("Failed to extract user fields from schema")
    except Exception as e:
        print(f"Error extracting user fields from schema: {e}")
        # Fallback to a hardcoded list of fields
        return [
            "username", "first_name", "last_name", "email", "phone_number",
            "location", "university", "field_of_interest", "high_school",
            "gender", "ethnicity", "uni_major", "job_title", "current_company",
            "profile_image_url", "linkedin_url", "recent_tags"
        ]

# Initialize USER_FIELDS with the fields from the schema
USER_FIELDS = get_user_fields_from_schema()

def process_contact_text(text: str) -> Tuple[Dict[str, Any], str]:
    """
    Process free-form text into a structured user object and additional notes.
    
    Args:
        text: Free-form text containing user information
        
    Returns:
        Tuple of (user_data, additional_notes)
    """
    # Define the system message to instruct the model
    system_message = f"""
    You are an assistant that extracts structured information about a person.
    Your task is to parse the free-form text about a person and extract:
    
    1. The standard fields about this person
    2. Any additional information that should be saved as notes
    
    The standard fields you should extract are: {", ".join(USER_FIELDS)}
    
    For any field where information is not available, use null.
    For the "username" field, create a username from the person's name if not explicitly provided.
    For the "recent_tags" field, leave as null (this will be handled separately).
    
    Return JSON with two keys:
    1. "user_data": An object containing all the standard fields
    2. "additional_notes": A string with any additional information that doesn't fit into the standard fields
    
    Ensure all standard fields are included, even if null.
    """

    try:
        # Make the request to OpenAI API
        response = openai.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": text}
            ],
            temperature=0.1,
            max_tokens=800
        )
        
        # Extract the response content
        result = response.choices[0].message.content
        
        # Parse the JSON response
        try:
            parsed_result = json.loads(result)
            user_data = parsed_result.get("user_data", {})
            additional_notes = parsed_result.get("additional_notes", "")
            
            # Ensure all fields are present
            for field in USER_FIELDS:
                if field not in user_data:
                    user_data[field] = None
            
            return user_data, additional_notes
            
        except json.JSONDecodeError as e:
            print(f"Error parsing response as JSON: {e}")
            print(f"Raw response: {result}")
            # Create a minimal user data structure with available text
            minimal_user_data = {"first_name": "Unknown", "last_name": "User"}
            return minimal_user_data, f"Error processing text. Original text: {text}"
            
    except Exception as e:
        print(f"Error processing contact text: {e}")
        # Create a minimal user data structure
        minimal_user_data = {"first_name": "Unknown", "last_name": "User"}
        return minimal_user_data, f"Error processing text. Original text: {text}"

def create_new_contact(contact_text: str, user_id: int, relationship_type: str = "contact") -> Dict[str, Any]:
    """
    Process text into a user profile and create a new contact relationship.
    
    Args:
        contact_text: Free-form text describing the contact
        user_id: ID of the user creating the contact
        relationship_type: Type of relationship to establish
        
    Returns:
        Dictionary with success status and new user information
    """
    # Process the contact text
    user_data, additional_notes = process_contact_text(contact_text)
    
    # Set default recent_tags if not provided
    if "recent_tags" not in user_data or not user_data["recent_tags"]:
        user_data["recent_tags"] = DEFAULT_TAGS
    
    try:
        # Create the user via API
        user_response = requests.post(
            f"{API_BASE_URL}/users", 
            json=user_data
        )
        
        if user_response.status_code != 201:
            error_msg = f"Failed to create user: {user_response.json().get('error', 'Unknown error')}"
            print(error_msg)
            return {"success": False, "message": error_msg}
        
        new_user = user_response.json()
        new_user_id = new_user.get("id")
        
        # Create the connection with the note containing additional information
        connection_data = {
            "user_id": user_id,
            "contact_id": new_user_id,
            "relationship_type": relationship_type,
            "note": additional_notes if additional_notes else None,
            "tags": user_data.get("recent_tags")
        }
        
        connection_response = requests.post(
            f"{API_BASE_URL}/connections", 
            json=connection_data
        )
        
        if connection_response.status_code != 201:
            error_msg = f"User created but failed to establish connection: {connection_response.json().get('error', 'Unknown error')}"
            print(error_msg)
            return {
                "success": True,
                "message": error_msg,
                "user": new_user,
                "connection_error": True
            }
        
        # Return success with the new user information
        result = {
            "success": True,
            "message": "Contact created successfully",
            "user": new_user,
            "notes": additional_notes
        }
        
        print(f"Created new contact: {new_user.get('first_name')} {new_user.get('last_name')}")
        if additional_notes:
            print(f"Additional notes: {additional_notes}")
        
        return result
        
    except Exception as e:
        error_msg = f"Error creating contact: {str(e)}"
        print(error_msg)
        return {"success": False, "message": error_msg}

if __name__ == "__main__":
    # Test the function with sample data
    sample_text = "John Doe is a software engineer at Google. He graduated from MIT with a computer science degree. His email is john.doe@example.com and phone is 123-456-7890. He lives in San Francisco."
    sample_user_id = 1
    
    success, message, result = create_new_contact(sample_text, sample_user_id)
    print(f"Success: {success}")
    print(f"Message: {message}")
    if not success:
        print(f"Error details: {result}")
    else:
        print(f"User: {result['user']}")
        if result['notes']:
            print(f"Additional notes: {result['notes']}") 