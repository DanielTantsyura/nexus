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

@app.route('/people', methods=['POST'])
def add_user():
    """Add a new user to the database."""
    data = request.json
    
    # Get username from URL query parameter, header, or JSON data
    username = request.args.get('username') or request.headers.get('X-Username') or data.get('username')
    
    # Validate required fields
    if not username:
        return jsonify({"error": "Missing required field: username"}), 400
        
    if 'first_name' not in data or 'last_name' not in data:
        return jsonify({"error": "Missing required fields: first_name and last_name"}), 400
    
    try:
        with db_manager:
            # Get the password from the data
            password = data.pop('password', None)
            
            # Ensure username is not in the data going to the people table
            # The API might have received it in the JSON body
            if 'username' in data:
                data.pop('username')
            
            # Add the user to the people table first
            user_id = db_manager.add_user(data)
            
            # Now create login entry with the username and password
            if username and password:
                db_manager.add_user_login(user_id, username, password)
            
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
            success = db_manager.add_connection(user_id, contact_id, relationship_description, custom_note, tags)
        
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
    
    # Map field names from API to database schema
    if 'relationship_type' in update_data:
        update_data['relationship_description'] = update_data.pop('relationship_type')
    
    # Handle note field - client may send either 'note' or 'notes'
    if 'note' in update_data:
        update_data['notes'] = update_data.pop('note')
    elif 'notes' in update_data:
        # Ensure it stays as 'notes' to match database column
        pass
    
    if not update_data:
        return jsonify({"error": "No fields to update"}), 400
    
    try:
        with db_manager:
            # Update the connection
            success = db_manager.update_connection(user_id, contact_id, update_data)
        
        if success:
            return jsonify({"message": "Connection updated successfully"})
        else:
            return jsonify({"error": "Failed to update connection"}), 500
    except Exception as e:
        error_message = f"Error updating connection: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

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
    
    try:
        # First check if the user exists
        with db_manager:
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
        
        # Process the contact text
        try:
            # Process text into a user profile and create a new contact
            created_contact = create_new_contact(
                contact_text=contact_text,
                user_id=user_id,
                relationship_type=relationship_type
            )
            
            return jsonify(created_contact), 201
        except Exception as e:
            error_message = f"Error processing contact text: {str(e)}"
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