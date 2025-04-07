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
    Return the specific user fields needed for contact creation.
    
    Returns:
        List of user field names
    """
    # Return the exact fields we need
    return [
        "first_name", "last_name", "email", "phone_number", 
        "gender", "ethnicity", "birthday", "location", 
        "high_school", "university", "uni_major", 
        "job_title", "current_company", "field_of_interest", 
        "profile_image_url", "linkedin_url"
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
    
    # If OpenAI is not available, use basic processing
    if not OPENAI_AVAILABLE or not OPENAI_WORKING:
        print("OpenAI API not available, using basic text processing")
        return basic_text_processing(text, USER_FIELDS)
    
    try:
        # Create a focused system prompt that explains what we want the model to do
        system_prompt = f"""
        Extract structured information from the provided text input.
        The text contains details about a person, and you need to extract specific fields to populate a user database.
        
        The database has the following fields:
        {', '.join(USER_FIELDS)}
        
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
            
            # Safely parse JSON
            try:
                extracted_data = json.loads(response_content)
            except json.JSONDecodeError as e:
                print(f"Invalid JSON from OpenAI: {response_content}")
                return basic_text_processing(text, USER_FIELDS)
            
            # Verify that we have at least first_name and last_name (required fields)
            if not extracted_data.get("first_name") or not extracted_data.get("last_name"):
                return False, None, "Could not extract first and last name from the text. Please provide clearer information."
            
            # Sanitize the data to ensure all fields are present
            for field in USER_FIELDS:
                if field not in extracted_data:
                    extracted_data[field] = None
                elif extracted_data[field] == "":
                    extracted_data[field] = None
            
            return True, extracted_data, "Successfully extracted user information."
        
        except Exception as e:
            print(f"Error processing text with OpenAI: {str(e)}")
            
            # Fallback to basic processing if API fails
            return basic_text_processing(text, USER_FIELDS)
    
    except Exception as e:
        print(f"Error processing text: {str(e)}")
        return False, None, "An error occurred while processing the text. Please try again later."

def basic_text_processing(text: str, fields: List[str]) -> Tuple[bool, Dict[str, Any], str]:
    """
    Basic text processing for when OpenAI is not available.
    
    Extract first and last name from text and set all other fields to None.
    
    Args:
        text: Free-form text containing user information
        fields: List of fields to include in user data
        
    Returns:
        Tuple containing success flag, user data, and message
    """
    words = text.strip().split()
    if len(words) < 2:
        return False, None, "At least first and last name are required."
    
    # Create a basic user object with just the first and last name
    user_data = {
        "first_name": words[0],
        "last_name": words[1] if len(words) > 1 else ""
    }
    
    # Add all other fields as None
    for field in fields:
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
    
    # Add username and recent_tags which are not part of USER_FIELDS
    # Generate username from first and last name
    first = user_data.get("first_name", "").lower().replace(" ", "")
    last = user_data.get("last_name", "").lower().replace(" ", "")
    user_data["username"] = f"{first}{last}"
    
    # Always set recent_tags to default
    user_data["recent_tags"] = DEFAULT_TAGS
    
    # Ensure birthday is properly formatted
    if user_data.get("birthday") and not isinstance(user_data["birthday"], str):
        user_data["birthday"] = str(user_data["birthday"])
    
    try:
        # Call the API to create the user
        api_url = f"{API_BASE_URL}/people"
        print(f"Creating user at URL: {api_url}")
        
        # Make a more robust API call without timeout
        try:
            user_response = requests.post(api_url, json=user_data)
            
            if user_response.status_code != 201:
                error_msg = f"Failed to create user: {user_response.text}"
                print(error_msg)
                return {"success": False, "message": error_msg}
            
            # Safely parse the response
            try:
                new_user = user_response.json()
            except json.JSONDecodeError:
                error_msg = "Error parsing API response"
                print(error_msg)
                return {"success": False, "message": error_msg}
            
            # Validate the response contains a user ID
            new_user_id = new_user.get("id")
            if not new_user_id:
                error_msg = "User created but no ID returned in response"
                print(error_msg)
                return {"success": False, "message": error_msg}
        except requests.exceptions.RequestException as e:
            error_msg = f"API call failed: {str(e)}"
            print(error_msg)
            return {"success": False, "message": error_msg}
        
        # Since the user was created, try to return success even if connection fails
        result = {
            "success": True,
            "message": "Contact created successfully",
            "user": new_user
        }
        
        # Try to create the connection as a separate step (that might fail)
        try:
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
            
            # Call without timeout
            connection_response = requests.post(relationship_url, json=connection_data)
            
            if connection_response.status_code != 201:
                result["message"] = "User created but connection failed. You can add the connection later."
                result["connection_error"] = True
                print(f"Connection creation failed with status {connection_response.status_code}")
            else:
                print(f"Created new contact: {new_user.get('first_name')} {new_user.get('last_name')}")
        except Exception as connection_err:
            # If connection creation fails, still return success for user creation
            result["message"] = "User created but connection failed. You can add the connection later."
            result["connection_error"] = True
            print(f"Error creating connection: {str(connection_err)}")
        
        return result
        
    except Exception as e:
        error_msg = f"Error creating contact: {str(e)}"
        print(error_msg)
        traceback.print_exc()  # Print full traceback for debugging
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