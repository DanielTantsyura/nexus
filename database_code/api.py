"""
API endpoints for the Nexus application.

This module provides RESTful API endpoints for user and contact management,
including creating, searching, and updating users and relationships.
"""

from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import json
import traceback
import os
import sys
print("Starting API with the following configuration:")
print(f"Python version: {sys.version}")
print(f"Current directory: {os.getcwd()}")
print(f"Files in current directory: {os.listdir('.')}")
print(f"Environment variables: PORT={os.environ.get('PORT')}, API_HOST={os.environ.get('API_HOST')}")

from database_operations import DatabaseManager
from newUser import process_contact_text, create_new_contact
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
                return jsonify(user)
            else:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
    except Exception as e:
        error_message = f"Error retrieving user: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/people/<int:user_id>/recent-tags', methods=['GET'])
def get_user_recent_tags(user_id):
    """Get recent tags used by a specific user."""
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
        return jsonify(connections)
    except Exception as e:
        error_message = f"Error retrieving user connections: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/connections', methods=['POST'])
def add_connection():
    """Add a new connection between two users."""
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_id', 'relationship_type']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_id = data['contact_id']
    relationship_description = data['relationship_type']
    custom_note = data.get('note')
    tags = data.get('tags')
    
    # Normalize tags to a comma-separated string regardless of input format
    if tags:
        if isinstance(tags, list):
            # If it's a list, join it into a comma-separated string
            tags_string = ",".join(tags)
        elif isinstance(tags, str):
            # If it's already a string, use it as is
            tags_string = tags
        else:
            # For any other type, convert to string
            tags_string = str(tags)
    else:
        tags_string = None
    
    try:
        with db_manager:
            # Check if both users exist
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            
            contact = db_manager.get_user_by_id(contact_id)
            if not contact:
                return jsonify({"error": f"Contact with ID {contact_id} not found"}), 404
            
            # Add the connection
            success = db_manager.add_connection(user_id, contact_id, relationship_description, custom_note, tags_string)
            
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
    """Update an existing connection between two users."""
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
        update_data['tags'] = ",".join(tags)
    
    # Map field names from API to database schema
    if 'relationship_type' in update_data:
        update_data['relationship_description'] = update_data.pop('relationship_type')
    
    if 'note' in update_data:
        update_data['notes'] = update_data.pop('note')
    
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
    """Create a new contact from text and establish a relationship."""
    data = request.json
    
    # Validate required fields
    required_fields = ['user_id', 'contact_text']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    user_id = data['user_id']
    contact_text = data['contact_text']
    relationship_type = data.get('relationship_type', 'contact')
    
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
    print(f"Contact creation request: user_id={user_id}, text_length={len(contact_text)}, relationship_type={relationship_type}, tags={custom_tags}")
    
    try:
        # First check if the user exists
        with db_manager:
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            print(f"Creating contact for user: {user.get('first_name')} {user.get('last_name')}")
        
        try:
            # Process text into structured user data
            print("Extracting contact information...")
            success, user_data, message = process_contact_text(contact_text)
            
            if not success or not user_data:
                return jsonify({"error": message}), 400
                
            # Add required fields that aren't part of the extraction
            first = user_data.get("first_name", "").lower().replace(" ", "")
            last = user_data.get("last_name", "").lower().replace(" ", "")
            user_data["username"] = f"{first}{last}"
            user_data["recent_tags"] = DEFAULT_TAGS
            
            # Directly use database operations to create the user
            with db_manager:
                print("Creating user in database...")
                try:
                    new_user_id = db_manager.add_user(user_data)
                    print(f"User created with ID: {new_user_id}")
                    
                    # Create connection directly in database
                    print("Creating connection in database...")
                    
                    # Get the note from the processed user data
                    note = user_data.get("note", "")
                    print(f"Using note: {note}")
                    
                    # Create the connection with the note and all custom tags in one operation
                    connection_success = db_manager.add_connection(
                        user_id, 
                        new_user_id,
                        relationship_type,
                        note,  # Use the LLM-extracted note
                        connection_tags  # Use all tags at once
                    )
                    
                    if connection_success:
                        print("Connection created successfully")
                        
                        # Update the user's recent tags if custom tags were provided
                        # This is just to update the user's recent tags list, not the connection itself
                        if custom_tags:
                            if isinstance(custom_tags, list) and len(custom_tags) > 0:
                                tag_list = custom_tags
                            elif isinstance(custom_tags, str):
                                tag_list = [tag.strip() for tag in custom_tags.split(',') if tag.strip()]
                            else:
                                tag_list = []
                                
                            if tag_list:
                                print(f"Updating recent tags for user {user_id} with: {tag_list}")
                                # Update the user's recent tags list for future tag suggestions
                                db_manager.update_user_recent_tags(user_id, tag_list)
                    else:
                        print("Connection creation failed")
                    
                    # Get the complete user object
                    new_user = db_manager.get_user_by_id(new_user_id)
                    
                    # Return success with user data
                    result = {
                        "success": True,
                        "message": "Contact created successfully",
                        "user": new_user,
                        "user_id": new_user_id,
                        "connection_error": not connection_success
                    }
                except Exception as db_error:
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
    
    port = int(os.environ.get("PORT", args.port))
    print(f"Starting API server on port {port}")
    app.run(host=API_HOST, port=port, debug=API_DEBUG) 