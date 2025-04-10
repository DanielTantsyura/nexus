"""
Module for processing free-form text into structured user data and creating new contacts.

This module uses the OpenAI API to extract structured information from
unstructured text descriptions, and provides functions to:
- Process contact text into user fields
- Generate relationship descriptions between users
- Ensure all input information is preserved in either structured fields or notes
"""

import json
import requests
import os
import re
import time
import traceback
from typing import Dict, Any, List, Tuple, Optional, Union

# OpenAI imports with fallback to older SDK
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

# Load environment variables
load_dotenv()

# Global variables
OPENAI_WORKING = False

# Initialize OpenAI client if available
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

# User fields from schema
def get_user_fields_from_schema() -> List[str]:
    """
    Return the specific user fields needed for contact creation.
    
    Returns:
        List of user field names
    """
    return [
        "first_name", "last_name", "email", "phone_number", 
        "gender", "ethnicity", "birthday", "location", 
        "high_school", "university", "uni_major", 
        "job_title", "current_company", "field_of_interest", 
        "profile_image_url", "linkedin_url"
    ]

USER_FIELDS = get_user_fields_from_schema()

#-----------------------
# Helper functions
#-----------------------

def _call_openai_api(
        system_prompt: str, 
        user_prompt: str, 
        model: str = OPENAI_MODEL, 
        temperature: float = 0.1, 
        max_tokens: int = 800
    ) -> Optional[str]:
    """
    Helper function to call the OpenAI API with proper error handling.
    
    Args:
        system_prompt: System prompt for the LLM
        user_prompt: User prompt/query for the LLM
        model: OpenAI model to use
        temperature: Sampling temperature (0.0 to 1.0)
        max_tokens: Maximum tokens in the response
        
    Returns:
        The generated content as a string, or None if an error occurred
    """
    if not OPENAI_AVAILABLE or not OPENAI_WORKING:
        print("OpenAI API not available")
        return None
    
    try:
        if USING_NEW_SDK:
            # New SDK format (1.x+)
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=temperature,
                max_tokens=max_tokens
            )
            # Extract the generated content
            return response.choices[0].message.content
        else:
            # Old SDK format (0.28.0)
            response = openai.ChatCompletion.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=temperature,
                max_tokens=max_tokens
            )
            # Extract the generated content
            return response.choices[0].message.content
    except Exception as e:
        print(f"Error calling OpenAI API: {str(e)}")
        return None

def _basic_text_extraction(text: str) -> Tuple[bool, Optional[Dict[str, Any]], str]:
    """
    Basic text extraction as a fallback when OpenAI is unavailable.
    
    Args:
        text: Free-form text containing user information
        
    Returns:
        Tuple with success flag, extracted data, and message
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
    for field in USER_FIELDS:
        if field not in user_data:
            user_data[field] = None
    
    # Put ALL remaining text in the note field to preserve information
    if len(words) > 2:
        user_data["note"] = text
    else:
        user_data["note"] = ""
    
    return True, user_data, "Basic processing only (OpenAI unavailable)."


#-----------------------
# Main public functions
#-----------------------

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
        return _basic_text_extraction(text)
    
    try:
        # Create a focused system prompt
        system_prompt = f"""
        Extract structured information from the provided text input.
        The text contains details about a person, and you need to extract specific fields to populate a user database.
        
        The database has the following fields:
        {', '.join(USER_FIELDS)}
        
        ADDITIONALLY, you need to extract a "note" field that contains ALL remaining information that doesn't fit into the structured fields above.
        
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
        9. CRITICAL: The note field MUST preserve ALL information from the original text that isn't captured in the structured fields.
           - Include relationship descriptions ("close friend", "met at a conference")
           - Include personal observations or context ("good at tennis", "knows my sister")
           - Include ANY other details not captured in structured fields (hobbies, personality traits, etc.)
           - If there's any doubt about whether information belongs in a structured field, include it in the note
           - Never discard any information from the input text
           - The user will be frustrated if any information they provided is lost
        10. If the note field would be empty after extracting structured fields, analyze the input again to ensure nothing was missed.
        
        Format your response as a valid JSON object with all these fields including note.
        """
        
        # Call OpenAI API
        response_content = _call_openai_api(system_prompt, text)
        
        if not response_content:
            # If API call failed, use basic text extraction
            return _basic_text_extraction(text)
        
        # Safely parse JSON
        try:
            extracted_data = json.loads(response_content)
        except json.JSONDecodeError as e:
            print(f"Invalid JSON from OpenAI: {response_content}")
            return _basic_text_extraction(text)
        
        # Verify that we have at least first_name and last_name (required fields)
        if not extracted_data.get("first_name") or not extracted_data.get("last_name"):
            return False, None, "Could not extract first and last name from the text. Please provide clearer information."
        
        # Sanitize the data to ensure all fields are present
        for field in USER_FIELDS:
            if field not in extracted_data:
                extracted_data[field] = None
            elif extracted_data[field] == "":
                extracted_data[field] = None
        
        # Ensure note field exists (may be None or empty string)
        if "note" not in extracted_data:
            # If note field is missing, create a default note that captures any remaining information
            structured_info = set()
            for field in USER_FIELDS:
                if extracted_data.get(field):
                    # Add the field value to the set of structured info
                    if isinstance(extracted_data[field], str):
                        structured_info.add(extracted_data[field].lower())
            
            # Create a note with any information not captured in structured fields
            # This is a fallback mechanism to ensure we don't lose information
            words = text.lower().split()
            remaining_info = []
            for word in words:
                word = word.strip('.,;:')
                if word and all(word not in info for info in structured_info):
                    remaining_info.append(word)
            
            if remaining_info:
                extracted_data["note"] = " ".join(remaining_info)
            else:
                extracted_data["note"] = ""
            
        print(f"Extracted note: {extracted_data.get('note', '')}")
        
        # Double-check that we haven't lost any significant information
        if not extracted_data.get("note") or len(extracted_data.get("note", "").strip()) < 10:
            # Check if the original text is significantly longer than what we've captured
            total_structured_length = sum(len(str(v) or "") for k, v in extracted_data.items() if k != "note" and v is not None)
            if len(text.strip()) > total_structured_length + 20:  # If we're missing significant content
                # Create a simple note with whatever might be missing
                extracted_data["note"] = f"Additional information: {text}"
        
        return True, extracted_data, "Successfully extracted user information."
    
    except Exception as e:
        print(f"Error processing text: {str(e)}")
        return False, None, "An error occurred while processing the text. Please try again later."

def generate_relationship_description(user_info: Dict[str, Any], contact_text: str, tags: List[str] = None) -> str:
    """
    Generate a relationship description between the current user and a new contact using LLM.
    
    Args:
        user_info: Dictionary containing the current user's information
        contact_text: Text description of the new contact
        tags: Optional list of tags associated with the relationship
        
    Returns:
        A natural language description of their relationship
    """
    # Default relationship type if something fails
    default_relationship = "Contact"
    
    # Check if OpenAI is available first
    if not OPENAI_AVAILABLE or not OPENAI_WORKING:
        print("OpenAI API not available, using default relationship type")
        return default_relationship
    
    try:
        # Validate user info
        if not user_info:
            print("No user information provided")
            return default_relationship
        
        # Create user profile with defensive dictionary access
        user_profile = {
            "name": f"{user_info.get('first_name', '')} {user_info.get('last_name', '')}".strip(),
            "location": user_info.get('location'),
            "high_school": user_info.get('high_school'),
            "university": user_info.get('university'),
            "uni_major": user_info.get('uni_major'),
            "job_title": user_info.get('job_title'),
            "current_company": user_info.get('current_company'),
            "field_of_interest": user_info.get('field_of_interest')
        }
        
        # Format user profile as a simple string - only include fields with values
        user_profile_text = "\n".join([f"{key}: {value}" for key, value in user_profile.items() if value])
        
        # Handle empty user profile
        if not user_profile_text.strip():
            print("User profile is empty, using default relationship type")
            return default_relationship
        
        # Tags info
        tags_info = ""
        if tags and len(tags) > 0:
            tags_info = f"Tags associated with this relationship: {', '.join(tags)}"
        
        # Create system prompt
        system_prompt = f"""
        You need to generate a brief, natural-sounding relationship description between two people.
        
        Information about the first person (current user):
        {user_profile_text}
        
        Information about the second person (new contact they're adding):
        {contact_text}
        
        {tags_info}
        
        Based on this information, describe their relationship in a brief phrase (1-5 words). 
        Examples: "College Friend", "Work Colleague", "Networking Contact", "Industry Peer", "Former Classmate", "Coworker", etc.
        
        Always capitalize the first letter of each word in your response.
        
        Just respond with the relationship description ONLY - no explanation or additional text.
        """
        
        # Call OpenAI API with increased robustness
        print("Calling OpenAI API to generate relationship description")
        response_content = _call_openai_api(
            system_prompt=system_prompt,
            user_prompt="Generate a relationship description",
            temperature=0.7,
            max_tokens=50
        )
        
        if not response_content:
            print("No response from OpenAI API, using default relationship")
            return default_relationship
        
        # Sanitize and validate
        relationship = response_content.strip()
        relationship = relationship.strip('"\'.,;:')
        if len(relationship) > 50:
            relationship = relationship[:50]
        
        # Ensure proper capitalization if not already capitalized
        words = relationship.split()
        if not words:
            print("Empty response from OpenAI API, using default relationship")
            return default_relationship
            
        if not all(w[0].isupper() for w in words if w and len(w) > 0):
            relationship = ' '.join(w.capitalize() for w in words if w)
        
        print(f"Generated relationship description: {relationship}")
        return relationship if relationship else default_relationship
        
    except Exception as e:
        print(f"Error in relationship generation: {str(e)}")
        traceback.print_exc()  # Full stack trace for debugging
        return default_relationship
