"""
Module for processing free-form text into structured user data and creating new users.
Uses OpenAI API to extract structured information from free-form text.
"""

import json
import requests
import os
import re
from typing import Dict, List, Tuple, Optional
from dotenv import load_dotenv
import openai
from config import DEFAULT_TAGS

# Load environment variables
load_dotenv()

# Initialize OpenAI API key (using older API version 0.28.0)
openai.api_key = os.getenv("OPENAI_API_KEY")
if not openai.api_key:
    print("Warning: OPENAI_API_KEY environment variable not set")

def get_user_fields_from_schema():
    """
    Dynamically extract user fields from the database schema in createDatabase.py.
    This ensures that the fields used in the API call always match the actual database schema.
    
    Returns:
        List of user field names
    """
    try:
        # Read the createDatabase.py file
        with open(os.path.join(os.path.dirname(__file__), 'createDatabase.py'), 'r') as file:
            schema_content = file.read()
        
        # Extract the CREATE TABLE users section
        users_table_match = re.search(r'CREATE TABLE users \(\s*(.*?)\s*\);', schema_content, re.DOTALL)
        if not users_table_match:
            raise ValueError("Could not find users table definition in createDatabase.py")
        
        users_table_def = users_table_match.group(1)
        
        # Extract field names using regex, excluding system fields like id and created_at
        field_matches = re.findall(r'^\s*(\w+)\s+', users_table_def, re.MULTILINE)
        
        # Filter out system fields that should not be exposed for user input
        excluded_fields = ['id', 'created_at']
        fields = [field for field in field_matches if field not in excluded_fields]
        
        if not fields:
            raise ValueError("No fields found in users table definition")
        
        return fields
    except Exception as e:
        print(f"Error extracting fields from schema: {e}")
        # Fallback to a hardcoded list of fields based on the known schema
        return [
            "username", "first_name", "last_name", "email", "phone_number",
            "birthday", "location", "high_school", "university", "field_of_interest",
            "current_company", "gender", "ethnicity", "uni_major", "job_title",
            "profile_image_url", "linkedin_url", "recent_tags"
        ]

# Get user database schema fields from the structure in createDatabase.py
USER_FIELDS = get_user_fields_from_schema()

def process_contact_text(text: str, tags: List[str], current_user_id: int) -> Tuple[bool, Optional[Dict], str]:
    """
    Process free-form text into a structured user object using OpenAI's GPT-4o-mini.
    
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
    # Basic validation - check if there's content
    if not text or len(text.strip()) < 5:
        return False, None, "Not enough information provided. Please provide more details."
    
    try:
        # Create a system prompt that explains what we want the model to do
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
        
        # Send the request to the OpenAI API using the older format (0.28.0)
        response = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": text}
            ],
            response_format={"type": "json_object"}
        )
        
        # Extract the generated JSON from the response
        response_content = response.choices[0].message.content
        extracted_data = json.loads(response_content)
        
        # Verify that we have at least first_name and last_name (required fields)
        if not extracted_data.get("first_name") or not extracted_data.get("last_name"):
            return False, None, "Could not extract first and last name from the text. Please provide clearer information."
        
        # Add default tags if not already present
        if "recent_tags" not in extracted_data or not extracted_data["recent_tags"]:
            extracted_data["recent_tags"] = DEFAULT_TAGS
        
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
        
        # Add all other fields as None
        for field in USER_FIELDS:
            if field not in user_data:
                user_data[field] = None
        
        # Ensure recent_tags is set to DEFAULT_TAGS
        user_data["recent_tags"] = DEFAULT_TAGS
        
        return True, user_data, "API processing failed. Used basic extraction instead."

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
    sample_text = "John Doe is a software engineer at Google. He graduated from MIT with a computer science degree. His email is john.doe@example.com and phone is 123-456-7890. He lives in San Francisco."
    sample_tags = ["tech", "friend", "work"]
    sample_user_id = 1
    
    success, message, user_id = create_new_contact(sample_text, sample_tags, sample_user_id)
    print(f"Success: {success}")
    print(f"Message: {message}")
    print(f"User ID: {user_id}") 