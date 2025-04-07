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
import traceback
from typing import Dict, Any, List, Tuple, Optional
try:
    # Try importing from newer OpenAI SDK (1.x+)
    from openai import OpenAI
    USING_NEW_SDK = True
except ImportError:
    # Fall back to older OpenAI SDK (0.28.0)
    import openai
    USING_NEW_SDK = False
from dotenv import load_dotenv
from config import DEFAULT_TAGS, OPENAI_MODEL, API_PORT, OPENAI_AVAILABLE, API_BASE_URL, IS_RAILWAY

# Only load API key from environment variables
load_dotenv()

# Track if OpenAI is available
OPENAI_WORKING = False

# Initialize OpenAI client with API key from environment only if API key is available
if OPENAI_AVAILABLE:
    try:
        if USING_NEW_SDK:
            client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            # Test the client with a simple call
            client.models.list()

            OPENAI_WORKING = True
        else:
            openai.api_key = os.getenv("OPENAI_API_KEY")
            # Test the API with a simple call
            openai.Model.list(limit=1)
            OPENAI_WORKING = True
        print("OpenAI API initialized successfully")
    except Exception as e:
        print(f"OpenAI API initialization failed: {e}")
        traceback.print_exc()
else:
    print("OpenAI API key not found - natural language processing features disabled")

# API endpoints
API_BASE_URL = API_BASE_URL
print(f"API_BASE_URL set to: {API_BASE_URL}")

def get_user_fields_from_schema() -> List[str]:
    """
    Dynamically extract user fields from the database schema in setupFiles/createDatabase.py.
    This ensures that the fields used in the API call always match the actual database schema.
    
    Returns:
        List of user field names
    """
    try:
        # Read the createDatabase.py file from setupFiles directory
        with open(os.path.join(os.path.dirname(__file__), 'setupFiles', 'createDatabase.py'), 'r') as file:
            schema_content = file.read()
        
        # Extract the CREATE TABLE people section
        users_table_match = re.search(r'CREATE TABLE people \(\s*(.*?)\s*\);', schema_content, re.DOTALL)
        if not users_table_match:
            raise ValueError("Could not find people table definition in createDatabase.py")
        
        users_table_def = users_table_match.group(1)
        
        # Extract field names using regex, excluding system fields like id and created_at
        field_matches = re.findall(r'^\s*(\w+)\s+', users_table_def, re.MULTILINE)
        
        # Filter out system fields that should not be exposed for user input
        excluded_fields = ['id', 'created_at']
        fields = [field for field in field_matches if field not in excluded_fields]
        
        if not fields:
            raise ValueError("No fields found in people table definition")
        
        return fields
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

def process_contact_text(text: str) -> Tuple[bool, Optional[Dict[str, Any]], str]:
    """
    Process free-form text into a structured user object and additional notes.
    
    Args:
        text: Free-form text containing user information
        
    Returns:
        Tuple containing:
        - Success flag (bool)
        - User data dictionary (Dict) or None if processing failed
        - Message string (success or error message)
    """
    # Basic validation - check if there's content
    if not text or len(text.strip()) < 5:
        return False, None, "Not enough information provided. Please provide more details."
    
    # Create a filtered list of fields that excludes username and recent_tags
    filtered_fields = [field for field in USER_FIELDS if field not in ['username', 'recent_tags']]
    
    # If OpenAI is not available, use basic processing
    if not OPENAI_AVAILABLE or not OPENAI_WORKING:
        print("OpenAI API not available, using basic text processing")
        return basic_text_processing(text, filtered_fields)
    
    try:
        # Create a system prompt that explains what we want the model to do
        system_prompt = f"""
        Extract structured information from the provided text input.
        The text contains details about a person, and you need to extract specific fields to populate a user database.
        
        The database has the following fields:
        {', '.join(filtered_fields)}
        
        IMPORTANT GUIDELINES:
        1. The input might be a formal paragraph or a shorthand note with brief biographical information.
        2. For shorthand notes like "Daniel Tantsyura CMU interested in real estate and entrepreneurship white male":
           - Extract university names (e.g., "CMU" → "Carnegie Mellon University" or just "CMU")
           - Extract interests even if they're not explicitly labeled (e.g., "interested in X and Y" → field_of_interest: "X and Y")
           - Identify demographic information like gender and ethnicity
        3. When multiple educational institutions are mentioned (e.g., "Stanford undergrad MIT PhD"):
           - Combine them in the university field as a comma-separated list (e.g., "Stanford, MIT")
        4. Parse dates in various formats and standardize to YYYY-MM-DD for the birthday field
        5. For each field, extract the relevant information from the input text if present
        6. If the information for a field is not provided, return null for that field
        7. Only extract first_name and last_name if they're clearly identifiable
        8. Don't guess or make up information that isn't in the text
        
        Format your response as a valid JSON object with these fields.
        """
        
        # Send the request to the OpenAI API
        try:
            if USING_NEW_SDK:
                # New SDK format (1.x+)
                response = client.chat.completions.create(
                    model=OPENAI_MODEL,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": text}
                    ],
                    temperature=0.1,
                    max_tokens=800
                )
                # Extract the generated JSON from the response
                response_content = response.choices[0].message.content
            else:
                # Old SDK format (0.28.0)
                response = openai.ChatCompletion.create(
                    model=OPENAI_MODEL,
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": text}
                    ],
                    temperature=0.1,
                    max_tokens=800
                )
                # Extract the generated JSON from the response
                response_content = response.choices[0].message.content
            
            extracted_data = json.loads(response_content)
            
            # Verify that we have at least first_name and last_name (required fields)
            if not extracted_data.get("first_name") or not extracted_data.get("last_name"):
                return False, None, "Could not extract first and last name from the text. Please provide clearer information."
            
            # Make sure username and recent_tags are not present
            if "username" in extracted_data:
                del extracted_data["username"]
                
            if "recent_tags" in extracted_data:
                del extracted_data["recent_tags"]
            
            return True, extracted_data, "Successfully extracted user information."
        
        except Exception as e:
            print(f"Error processing text with OpenAI: {str(e)}")
            
            # Fallback to basic processing if API fails
            words = text.strip().split()
            if len(words) < 2:
                return False, None, "At least first and last name are required."
            
            # Create a basic user object with just the required fields
            user_data = {
                "first_name": words[0],
                "last_name": words[1]
            }
            
            # Add all other fields as None for filtered fields only
            for field in filtered_fields:
                if field not in user_data:
                    user_data[field] = None
            
            return True, user_data, "API processing failed. Used basic extraction instead."
    
    except Exception as e:
        print(f"Error processing text: {str(e)}")
        return False, None, "An error occurred while processing the text. Please try again later."

def basic_text_processing(text: str, filtered_fields: List[str]) -> Tuple[bool, Dict[str, Any], str]:
    """Basic text processing for when OpenAI is not available."""
    words = text.strip().split()
    if len(words) < 2:
        return False, None, "At least first and last name are required."
    
    # Create a basic user object with just the required fields
    user_data = {
        "first_name": words[0],
        "last_name": words[1] if len(words) > 1 else ""
    }
    
    # Add all other fields as None for filtered fields only
    for field in filtered_fields:
        if field not in user_data:
            user_data[field] = None
    
    return True, user_data, "Basic processing only (OpenAI unavailable)."

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
    success, user_data, message = process_contact_text(contact_text)
    
    if not success or not user_data:
        return {"success": False, "message": message}
    
    # Set default recent_tags if not provided
    if "recent_tags" not in user_data or not user_data["recent_tags"]:
        user_data["recent_tags"] = DEFAULT_TAGS
    
    try:
        # Call the API to create the user
        api_url = f"{API_BASE_URL}/people"
        print(f"Creating user at URL: {api_url}")
        user_response = requests.post(api_url, json=user_data)
        
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
            "note": contact_text,  # Store the original text as a note
            "tags": DEFAULT_TAGS.split(',')[0]  # Use first default tag
        }
        
        # Call the API to create the relationship
        relationship_url = f"{API_BASE_URL}/connections"
        print(f"Creating connection at URL: {relationship_url}")
        connection_response = requests.post(relationship_url, json=connection_data)
        
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
            "user": new_user
        }
        
        print(f"Created new contact: {new_user.get('first_name')} {new_user.get('last_name')}")
        
        return result
        
    except Exception as e:
        error_msg = f"Error creating contact: {str(e)}"
        print(error_msg)
        return {"success": False, "message": error_msg}

if __name__ == "__main__":
    # Test the function with sample data
    sample_text = "John Doe is a software engineer at Google. He graduated from MIT with a computer science degree. His email is john.doe@example.com and phone is 123-456-7890. He lives in San Francisco."
    sample_user_id = 1
    
    result = create_new_contact(sample_text, sample_user_id)
    print(f"Success: {result.get('success', False)}")
    print(f"Message: {result.get('message', 'No message')}")
    if not result.get('success', False):
        print(f"Error details: {result}")
    else:
        print(f"User: {result.get('user', {})}") 