"""
API endpoints for the Nexus application.

This module provides RESTful API endpoints for user and contact management,
including creating, searching, and updating users and relationships.

Key features include:
- User authentication and account management
- Contact creation from free-form text using NLP
- Relationship management with custom tags and notes
- Intelligent relationship description generation using OpenAI
- Tag processing and management for connection categorization

The API provides integration between the Swift frontend and the Python backend,
handling data transformation, validation, and persistent storage.
"""

from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import json
import traceback
import os
import sys
import concurrent.futures
print("Starting API with the following configuration:")
print(f"Python version: {sys.version}")
print(f"Current directory: {os.getcwd()}")
print(f"Files in current directory: {os.listdir('.')}")
print(f"Environment variables: PORT={os.environ.get('PORT')}, API_HOST={os.environ.get('API_HOST')}")

from database_operations import DatabaseManager
from newContact import process_contact_text, generate_relationship_description
from config import API_HOST, API_PORT, DATABASE_URL, API_DEBUG, DEFAULT_TAGS
print(f"Config loaded: API_HOST={API_HOST}, API_PORT={API_PORT}, DATABASE_URL={DATABASE_URL} (truncated for security)")
import argparse
import uuid
import time
from datetime import datetime

app = Flask(__name__)
app.debug = API_DEBUG
# Enable CORS for all routes
CORS(app, resources={r"/*": {"origins": "*"}})

# Create a single database manager instance
db_manager = DatabaseManager(DATABASE_URL)

@app.route('/', methods=['GET'])
def root():
    """API root endpoint returns a status message."""
    try:
        # Try a simple database connection test
        with db_manager:
            db_status = "connected" if db_manager.is_connected() else "disconnected"
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    return jsonify({
        "status": "API is running",
        "database": db_status,
        "environment": os.environ.get("RAILWAY_ENVIRONMENT", "development")
    })

@app.route('/people', methods=['GET'])
def get_all_users():
    """Get all users from the database."""
    try:
        with db_manager:
            users = db_manager.get_all_users()
        return jsonify(users)
    except Exception as e:
        error_message = f"Error retrieving users: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people/<int:user_id>', methods=['GET'])
def get_user_by_id(user_id):
    """Get a specific user by ID."""
    try:
        with db_manager:
            user = db_manager.get_user_by_id(user_id)
            if user:
                # Log detailed information about the user data
                print(f"User data retrieved for ID {user_id}")
                print(f"User data contains birthday: {'birthday' in user}")
                if 'birthday' in user:
                    print(f"Birthday value: {user['birthday']}")
                else:
                    print("WARNING: 'birthday' field missing from user data")
                    print(f"Available fields: {list(user.keys())}")
                    
                    # Add the birthday field if it's missing from the result
                    # This is a temporary fix that ensures the API returns a consistent schema
                    user['birthday'] = None
                    print("Added 'birthday' field with None value")
                
                return jsonify(user)
            else:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
    except Exception as e:
        error_message = f"Error retrieving user: {str(e)}"
        print(error_message)
        traceback.print_exc()  # Print detailed error information
        return jsonify({"error": error_message}), 500

@app.route('/people/<int:user_id>/recent-tags', methods=['GET'])
def get_user_recent_tags(user_id):
    """
    Get recent tags used by a specific user.
    
    This endpoint retrieves the tags that a user has recently used when creating
    or updating connections. These tags can be used to suggest commonly used
    relationship categories for new connections.
    
    Path Parameters:
        - user_id: ID of the user whose recent tags to retrieve
        
    Response:
        - JSON array of strings representing tags
        - Empty array if the user has no recent tags
        - 404 error if the user does not exist
    """
    try:
        with db_manager:
            # Check if user exists
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            
            # Fetch recent tags for the user
            tags = db_manager.get_user_recent_tags(user_id)
            
            # If no tags, return empty list
            if not tags:
                return jsonify([])
                
            return jsonify(tags)
    except Exception as e:
        error_message = f"Error retrieving recent tags: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people', methods=['POST'])
def add_user():
    """Add a new user to the database."""
    data = request.json
    
    # Validate required fields
    required_fields = ['username', 'first_name', 'last_name']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    try:
        with db_manager:
            # Add the user
            user_id = db_manager.add_user(data)
            
            # Add login if provided
            if 'password' in data:
                db_manager.add_user_login(user_id, data['username'], data['password'])
            
            # Get the newly created user
            new_user = db_manager.get_user_by_id(user_id)
        
        return jsonify(new_user), 201
    except Exception as e:
        error_message = f"Error adding user: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update an existing user."""
    data = request.json
    try:
        with db_manager:
            success = db_manager.update_user(user_id, data)
            if success:
                updated_user = db_manager.get_user_by_id(user_id)
                return jsonify(updated_user)
            else:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
    except Exception as e:
        error_message = f"Error updating user: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people/search', methods=['GET'])
def search_users():
    """Search for users by name, location, or interests."""
    search_term = request.args.get('q', '')
    if not search_term:
        return jsonify({"error": "Search term is required"}), 400
    
    try:
        with db_manager:
            results = db_manager.search_users(search_term)
        return jsonify(results)
    except Exception as e:
        error_message = f"Error searching users: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people/<int:user_id>/connections', methods=['GET'])
def get_user_connections(user_id):
    """Get all connections for a specific user."""
    try:
        with db_manager:
            connections = db_manager.get_user_connections(user_id)
            
            # Ensure all connections have the birthday field (even if null)
            for conn in connections:
                if 'birthday' not in conn:
                    conn['birthday'] = None
                    print(f"WARNING: Added missing 'birthday' field to connection {conn.get('id')}")
            
            # Log the first connection data for debugging
            if connections and len(connections) > 0:
                first_conn = connections[0]
                print(f"Sample connection data (first connection):")
                print(f"  ID: {first_conn.get('id')}")
                print(f"  Name: {first_conn.get('first_name')} {first_conn.get('last_name')}")
                print(f"  Birthday: {first_conn.get('birthday')}")
            
            return jsonify(connections)
    except Exception as e:
        error_message = f"Error retrieving user connections: {str(e)}"
        print(error_message)
        traceback.print_exc()  # Print detailed error information
        return jsonify({"error": error_message}), 500

@app.route('/connections', methods=['POST'])
def add_connection():
    """
    Add a new connection between two users.
    
    This endpoint creates a bidirectional relationship between two users, with
    additional metadata such as relationship description, notes, and tags.
    
    Request:
        - user_id: ID of the user creating the connection
        - contact_id: ID of the user to connect with
        - relationship_description: A short description of the relationship (e.g., "College Friend")
        - note: Optional. Additional notes about the relationship
        - tags: Optional. List or comma-separated string of tags to categorize the relationship
        
    Response:
        - Success message if the connection was created
        - Error message if the operation failed
        
    Notes:
        - If tags are provided, they are also added to the user's recent tags list
        - Handles both list and string formats for tags
    """
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_id', 'relationship_description']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_id = data['contact_id']
    relationship_description = data['relationship_description']
    custom_note = data.get('note')
    tags = data.get('tags')
    
    # Process tags into a comma-separated string for the database
    if tags and isinstance(tags, list) and len(tags) > 0:
        print(f"Custom tags provided as list: {tags}")
        # Join all tags into a comma-separated string for the database
        connection_tags = ",".join(tags)
    elif tags and isinstance(tags, str) and tags.strip():
        print(f"Custom tags provided as string: {tags}")
        # Use the string directly
        connection_tags = tags
    else:
        print("No custom tags provided, leaving tags empty")
        # Explicitly set to None for empty lists, empty strings or null values
        connection_tags = None
    
    try:
        with db_manager:
            # Check if both users exist
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            
            contact = db_manager.get_user_by_id(contact_id)
            if not contact:
                return jsonify({"error": f"Contact with ID {contact_id} not found"}), 404
            
            # Add the connection - API uses relationship_description but DB expects relationship_description
            success = db_manager.add_connection(user_id, contact_id, relationship_description, custom_note, connection_tags)
            
            # Update the user's recent tags if tags were provided
            if success and tags:
                if isinstance(tags, str):
                    tag_list = [tag.strip() for tag in tags.split(',') if tag.strip()]
                elif isinstance(tags, list):
                    tag_list = [tag for tag in tags if tag]
                else:
                    tag_list = []
                
                if tag_list:
                    print(f"Updating recent tags for user {user_id} with: {tag_list}")
                    db_manager.update_user_recent_tags(user_id, tag_list)
        
        if success:
            return jsonify({"message": "Connection added successfully"}), 201
        else:
            return jsonify({"error": "Failed to add connection"}), 500
    except Exception as e:
        error_message = f"Error adding connection: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/connections', methods=['PUT'])
def update_connection():
    """
    Update an existing connection between two users.
    
    This endpoint modifies the metadata for a connection between two users, 
    such as relationship description, notes, and tags.
    
    Request:
        - user_id: ID of the user who owns the connection
        - contact_id: ID of the connected user
        - relationship_description: Optional. Updated description of the relationship
        - note: Optional. Updated notes about the relationship
        - tags: Optional. Updated list or comma-separated string of tags
        
    Response:
        - Success message if the connection was updated
        - Error message if the operation failed
        
    Notes:
        - If tags are provided, they are also added to the user's recent tags list
        - Empty tag lists or strings result in NULL tag values in the database
        - Field names are mapped from API convention (note) to database convention (notes)
    """
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_id']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_id = data['contact_id']
    
    # Remove the ID fields from the data
    update_data = {k: v for k, v in data.items() if k not in ['user_id', 'contact_id']}
    
    # Extract tags before mapping field names
    tags = update_data.get('tags')
    
    # Normalize tags to a string format if it's an array
    if tags and isinstance(tags, list):
        if len(tags) > 0:
            update_data['tags'] = ",".join(tags)
        else:
            # Handle empty arrays by setting tags to None
            update_data['tags'] = None
    elif tags == []:
        # Also catch any empty list that might have been missed
        update_data['tags'] = None
    elif tags == "":
        # Empty string should also be converted to NULL
        update_data['tags'] = None
    
    # Map field names from API to database schema
    # The API uses 'relationship_description' but the DB and Swift model expect 'relationship_description'
    if 'relationship_description' in update_data:
        update_data['relationship_description'] = update_data.pop('relationship_description')
    
    if 'note' in update_data:
        update_data['notes'] = update_data.pop('note')
    
    # what_they_are_working_on doesn't need renaming as it matches the DB column name
    
    if not update_data:
        return jsonify({"error": "No fields to update"}), 400
    
    try:
        with db_manager:
            # Update the connection
            success = db_manager.update_connection(user_id, contact_id, update_data)
            
            # Update the user's recent tags if tags were updated
            if success and tags:
                # Handle both string and array formats for tags
                if isinstance(tags, str):
                    tag_list = [tag.strip() for tag in tags.split(',') if tag.strip()]
                elif isinstance(tags, list):
                    tag_list = tags
                else:
                    tag_list = []
                    
                if tag_list:
                    print(f"Updating recent tags for user {user_id} with: {tag_list}")
                    db_manager.update_user_recent_tags(user_id, tag_list)
        
        if success:
            return jsonify({"message": "Connection updated successfully"})
        else:
            return jsonify({"error": "Failed to update connection"}), 500
    except Exception as e:
        error_message = f"Error updating connection: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/connections/update', methods=['PUT'])
def update_connection_compat():
    """Update an existing connection between two users - compatibility endpoint."""
    # Just delegate to the main update_connection function
    return update_connection()

@app.route('/connections', methods=['DELETE'])
def remove_connection():
    """Remove a connection between two users."""
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_id']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_id = data['contact_id']
    
    try:
        with db_manager:
            # Check if both users exist
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            
            contact = db_manager.get_user_by_id(contact_id)
            if not contact:
                return jsonify({"error": f"Contact with ID {contact_id} not found"}), 404
            
            # Remove the connection
            success = db_manager.remove_connection(user_id, contact_id)
        
        if success:
            return jsonify({"message": "Connection removed successfully"})
        else:
            return jsonify({"error": "Failed to remove connection"}), 500
    except Exception as e:
        error_message = f"Error removing connection: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/contacts/create', methods=['POST'])
def create_contact():
    """
    Create a new contact from text and establish a relationship.
    
    This endpoint accepts free-form text describing a person, processes it using NLP,
    and creates a new user record with structured information. It then establishes a 
    connection between the current user and the newly created contact.
    
    The relationship description is generated using the current user's profile information,
    the contact text, and any provided tags to create a contextual and meaningful label.
    
    Request:
        - user_id: ID of the user creating the contact
        - contact_text: Free-form text describing the contact
        - tags: Optional. List or comma-separated string of tags to associate with the contact
        
    Response:
        - success: Boolean indicating success
        - message: Success or error message
        - user: Complete user data for the newly created contact
        - user_id: ID of the newly created contact
        - connection_error: Boolean indicating if connection creation failed
    """
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_text']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_text = data['contact_text']
    relationship_description = 'Contact'
    
    # Get custom tags if provided in the request
    custom_tags = data.get('tags', [])
    
    # Process tags into a comma-separated string for the database
    if custom_tags and isinstance(custom_tags, list) and len(custom_tags) > 0:
        print(f"Custom tags provided as list: {custom_tags}")
        # Join all tags into a comma-separated string for the database
        connection_tags = ",".join(custom_tags)
    elif custom_tags and isinstance(custom_tags, str) and custom_tags.strip():
        print(f"Custom tags provided as string: {custom_tags}")
        # Use the string directly
        connection_tags = custom_tags
    else:
        print("No custom tags provided, leaving tags empty")
        # Don't use any default tag
        connection_tags = None
    
    # Log request info for debugging
    print(f"Contact creation request: user_id={user_id}, text_length={len(contact_text)}, tags={custom_tags}")
    
    try:
        # First check if the user exists
        with db_manager:
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            print(f"Creating contact for user: {user.get('first_name')} {user.get('last_name')}")
        
        try:
            # Create tag list for relationship generation
            tag_list = []
            if custom_tags:
                if isinstance(custom_tags, list):
                    tag_list = custom_tags
                    print(f"DEBUG: Using custom_tags as list: {tag_list}")
                elif isinstance(custom_tags, str):
                    tag_list = [tag.strip() for tag in custom_tags.split(',') if tag.strip()]
                    print(f"DEBUG: Converted custom_tags string to list: {tag_list}")
            # Get the processed contact data
            print(f"Processing contact text for user_id={user_id}")
            success, user_data, message = process_contact_text(contact_text)
            print(f"Contact processing result: success={success}, message='{message}'")
            
            if not success or not user_data:
                print(f"Contact processing failed: {message}")
                return jsonify({"error": message}), 400

            # Get the current user information
            print(f"Fetching user information for ID: {user_id}")
            with db_manager:
                current_user = db_manager.get_user_by_id(user_id)
                if not current_user:
                    print(f"Warning: Could not get user information for ID: {user_id}")
                    return jsonify({"error": "Could not retrieve current user information"}), 500

            # Get the relationship description
            print(f"Generating relationship description with {len(tag_list)} tags")
            relationship_description = generate_relationship_description(current_user, contact_text, tag_list)
            print(f"Generated relationship description: '{relationship_description}'")
            
            # Directly use database operations to create the user
            with db_manager:
                print("Creating user in database...")
                try:
                    print(f"DEBUG: Adding user with data: {user_data}")
                    new_user_id = db_manager.add_user(user_data)
                    print(f"User created with ID: {new_user_id}")
                    
                    # Create connection directly in database
                    print("Creating connection in database...")
                    
                    # Get the note from the processed user data
                    note = user_data.get("note", "")
                    print(f"Using note: {note}")
                    
                    # Create the connection with the note and all custom tags in one operation
                    # Swift model expects relationship_description
                    print(f"DEBUG: Adding connection - user_id: {user_id}, new_user_id: {new_user_id}, relationship: {relationship_description}, tags: {connection_tags}")
                    connection_success = db_manager.add_connection(
                        user_id, 
                        new_user_id,
                        relationship_description,  # This will be used as relationship_description in the DB
                        note,  # Use the LLM-extracted note
                        connection_tags,  # Use all tags at once
                        user_data.get("what_they_are_working_on")  # Pass the extracted work information
                    )
                    
                    if connection_success:
                        print("Connection created successfully")
                        
                        # Update the user's recent tags if custom tags were provided
                        # This is just to update the user's recent tags list, not the connection itself
                        if custom_tags:
                            if isinstance(custom_tags, list) and len(custom_tags) > 0:
                                tag_list = custom_tags
                                print(f"DEBUG: Using custom_tags list for recent tags update: {tag_list}")
                            elif isinstance(custom_tags, str):
                                tag_list = [tag.strip() for tag in custom_tags.split(',') if tag.strip()]
                                print(f"DEBUG: Converted custom_tags string for recent tags update: {tag_list}")
                            else:
                                tag_list = []
                                print("DEBUG: No valid custom_tags for recent tags update")
                                
                            if tag_list:
                                print(f"Updating recent tags for user {user_id} with: {tag_list}")
                                # Update the user's recent tags list for future tag suggestions
                                db_manager.update_user_recent_tags(user_id, tag_list)
                                print("DEBUG: Recent tags updated successfully")
                    else:
                        print("Connection creation failed")
                    
                    # Get the complete user object
                    print(f"DEBUG: Retrieving complete user data for ID: {new_user_id}")
                    new_user = db_manager.get_user_by_id(new_user_id)
                    
                    # Return success with user data
                    result = {
                        "success": True,
                        "message": "Contact created successfully",
                        "user": new_user,
                        "user_id": new_user_id,
                        "connection_error": not connection_success
                    }
                    print(f"DEBUG: Returning success response with user_id: {new_user_id}, connection_error: {not connection_success}")
                except Exception as db_error:
                    print(f"DEBUG: Database operation failed with error: {str(db_error)}")
                    traceback.print_exc()
                    return jsonify({"error": f"Database error: {str(db_error)}"}), 500
                    
            return jsonify(result), 201
        except Exception as e:
            error_message = f"Error processing contact: {str(e)}"
            print(error_message)
            traceback.print_exc()
            return jsonify({"error": error_message}), 500
    except Exception as e:
        error_message = f"Error creating contact: {str(e)}"
        print(error_message)
        traceback.print_exc()
        return jsonify({"error": error_message}), 500

@app.route('/login', methods=['POST'])
def login():
    """
    Login route to authenticate users.
    
    Request:
        - username: user's username
        - password: user's password
        
    Response:
        - JSON with user_id if successful
        - Error message if login fails
    """
    try:
        data = request.get_json()
        
        if not data or 'username' not in data or 'password' not in data:
            return jsonify({
                'status': 'error',
                'message': 'Username and password are required'
            }), 400
        
        username = data['username']
        passkey = data['password']  # Map password to passkey
        
        # Connect to database and validate login
        with db_manager:
            user_id = db_manager.validate_login(username, passkey)
            
            if user_id:
                # Update last login
                db_manager.update_last_login(user_id)
                
                # Get basic user info
                user = db_manager.get_user_by_id(user_id)
                
                return jsonify({
                    'status': 'success',
                    'user_id': user_id,
                    'user': user
                })
            else:
                return jsonify({
                    'status': 'error',
                    'message': 'Invalid username or password'
                }), 401
    except Exception as e:
        print(f"Login error: {e}")
        return jsonify({
            'status': 'error',
            'message': f'Login service unavailable. Please try again later. Error: {str(e)}'
        }), 500

@app.route('/people/<int:user_id>/update-last-login', methods=['POST'])
def update_last_login(user_id):
    """Update the last_login timestamp for a user when the app is opened."""
    try:
        with db_manager:
            # Check if user exists
            user = db_manager.get_user_by_id(user_id)
            if not user:
                print(f"User with ID {user_id} not found when updating last login")
                # Return success even if user not found to avoid client errors
                return jsonify({"message": "User not found but operation recorded"}), 200
            
            # Update last login timestamp
            success = db_manager.update_last_login(user_id)
            
            if success:
                return jsonify({"message": "Last login timestamp updated successfully"})
            else:
                return jsonify({"message": "No update needed for last login"}), 200
    except Exception as e:
        error_message = f"Error updating last login timestamp: {str(e)}"
        print(error_message)
        # Return success to avoid client errors
        return jsonify({"message": "Error recorded but continuing operation"}), 200

@app.route('/diagnostic', methods=['GET'])
def diagnostic():
    """Diagnostic endpoint to check system status."""
    result = {
        "api_status": "running",
        "timestamp": datetime.now().isoformat(),
        "environment": os.environ.get("RAILWAY_ENVIRONMENT", "development"),
        "python_version": sys.version,
        "working_directory": os.getcwd(),
        "environment_variables": {
            "PORT": os.environ.get("PORT"),
            "API_HOST": os.environ.get("API_HOST"),
            "DATABASE_URL_EXISTS": os.environ.get("DATABASE_URL") is not None,
            "OPENAI_API_KEY_EXISTS": os.environ.get("OPENAI_API_KEY") is not None
        },
        "config": {
            "API_HOST": API_HOST,
            "API_PORT": API_PORT,
            "API_DEBUG": API_DEBUG,
            "DATABASE_URL_LENGTH": len(DATABASE_URL) if DATABASE_URL else 0
        }
    }
    
    # Test database connection
    try:
        with db_manager:
            if db_manager.is_connected():
                result["database"] = {
                    "status": "connected",
                    "test_query": "successful" 
                }
            else:
                result["database"] = {
                    "status": "disconnected",
                    "error": "Not connected but no exception thrown"
                }
    except Exception as e:
        result["database"] = {
            "status": "error",
            "error": str(e),
            "traceback": traceback.format_exc()
        }
    
    return jsonify(result)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run the Nexus API server')
    parser.add_argument('--port', type=int, default=API_PORT, 
                        help=f'Port to run the server on (default: {API_PORT})')
    args = parser.parse_args()
    
    # Ensure database schema is up to date
    try:
        with db_manager:
            print("Checking and updating database schema...")
            db_manager.ensure_birthday_field_exists()
    except Exception as e:
        print(f"Error checking database schema: {e}")
    
    port = int(os.environ.get("PORT", args.port))
    print(f"Starting API server on port {port}")
    app.run(host=API_HOST, port=port, debug=API_DEBUG) 