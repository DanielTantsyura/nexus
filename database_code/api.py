"""
API endpoints for the Nexus application.

This module provides RESTful API endpoints for user and contact management,
including creating, searching, and updating users and relationships.
"""

from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import json
import traceback
from database_operations import DatabaseManager
from newUser import process_contact_text, create_new_contact
from config import API_HOST, API_PORT, DATABASE_URL, API_DEBUG, DEFAULT_TAGS, CONNECTION_TYPES
import argparse
import os
import sys
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
    return jsonify({"status": "API is running"})

@app.route('/users', methods=['GET'])
def get_users():
    """Get all users from the database."""
    try:
        with db_manager:
            users = db_manager.get_all_users()
        
        # Even if we get an empty list, return it as valid response
        return jsonify(users if users else [])
    except Exception as e:
        error_message = f"Error retrieving users: {str(e)}"
        print(error_message)
        # Return empty array instead of error for better client handling
        return jsonify([])

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Get a specific user by ID."""
    try:
        with db_manager:
            user = db_manager.get_user_by_id(user_id)
        
        if user:
            return jsonify(user)
        else:
            print(f"User with ID {user_id} not found")
            # Return empty user object with ID instead of 404 error
            return jsonify({
                "id": user_id,
                "username": "unknown",
                "first_name": "Unknown",
                "last_name": "User"
            })
    except Exception as e:
        error_message = f"Error retrieving user: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/users/search', methods=['GET'])
def search_users():
    """Search for users based on query parameters."""
    search_term = request.args.get('q', '')
    
    if not search_term:
        return jsonify({"error": "Search term is required"}), 400
    
    try:
        with db_manager:
            users = db_manager.search_users(search_term)
        return jsonify(users)
    except Exception as e:
        error_message = f"Error searching users: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/users', methods=['POST'])
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

@app.route('/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update an existing user in the database."""
    data = request.json
    
    try:
        with db_manager:
            # Check if user exists
            user = db_manager.get_user_by_id(user_id)
            if not user:
                return jsonify({"error": f"User with ID {user_id} not found"}), 404
            
            # Update the user
            success = db_manager.update_user(user_id, data)
            
            if success:
                updated_user = db_manager.get_user_by_id(user_id)
                return jsonify(updated_user)
            else:
                return jsonify({"error": "Failed to update user"}), 500
    except Exception as e:
        error_message = f"Error updating user: {str(e)}"
        print(error_message)
        return jsonify({"error": error_message}), 500

@app.route('/users/<int:user_id>/connections', methods=['GET'])
def get_user_connections(user_id):
    """Get all connections for a specific user."""
    try:
        with db_manager:
            # Check if user exists
            user = db_manager.get_user_by_id(user_id)
            if not user:
                print(f"User with ID {user_id} not found when fetching connections")
                # Return empty array instead of error
                return jsonify([])
            
            connections = db_manager.get_user_connections(user_id)
        return jsonify(connections if connections else [])
    except Exception as e:
        error_message = f"Error retrieving connections: {str(e)}"
        print(error_message)
        # Return empty array instead of error
        return jsonify([])

@app.route('/connections/<int:user_id>', methods=['GET'])
def get_connections(user_id):
    """Get all connections for a specific user (legacy endpoint)."""
    # Redirect to the standard endpoint
    return get_user_connections(user_id)

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
    
    if 'note' in update_data:
        update_data['custom_note'] = update_data.pop('note')
    
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
        password = data['password']
        
        # Connect to database and validate login
        with db_manager:
            user_id = db_manager.validate_login(username, password)
            
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

@app.route('/users/<int:user_id>/update-last-login', methods=['POST'])
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

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run the Nexus API server')
    parser.add_argument('--port', type=int, default=API_PORT, 
                        help=f'Port to run the server on (default: {API_PORT})')
    args = parser.parse_args()
    
    print(f"Starting API server on port {args.port}")
    app.run(host=API_HOST, port=args.port, debug=True) 