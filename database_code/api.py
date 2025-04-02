from flask import Flask, jsonify, request
from database_operations import DatabaseManager
from flask_cors import CORS
from config import API_HOST, API_PORT, API_DEBUG, DEFAULT_TAGS
import newUser  # Import the new contact processing module
import random

app = Flask(__name__)
CORS(app)  # Enable cross-origin requests

# Initialize database connection
db = DatabaseManager()

@app.route('/users', methods=['GET'])
def get_users():
    """Get all users from the database."""
    db.connect()
    try:
        users = db.get_all_users()
        return jsonify(users)
    finally:
        db.disconnect()

@app.route('/users', methods=['POST'])
def add_user():
    """Add a new user to the database."""
    user_data = request.json
    
    # Validate required fields
    required_fields = ['first_name', 'last_name']
    for field in required_fields:
        if field not in user_data or not user_data[field]:
            return jsonify({"error": f"Missing required field: {field}"}), 400
    
    # Remove recent_tags if it was provided
    if 'recent_tags' in user_data:
        del user_data['recent_tags']
    
    db.connect()
    try:
        user_id = db.add_user(user_data)
        return jsonify({"id": user_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.disconnect()

@app.route('/contacts/create', methods=['POST'])
def create_contact():
    """Create a new contact from free-form text and establish a relationship."""
    data = request.json
    
    # Validate required fields
    if 'text' not in data or not data['text']:
        return jsonify({"error": "No contact text provided"}), 400
    
    if 'user_id' not in data or not data['user_id']:
        return jsonify({"error": "User ID is required"}), 400
    
    # Extract data
    text = data['text']
    user_id = data['user_id']
    tags = data.get('tags', [])
    
    # Process the text and create the contact
    success, message, new_user_id = newUser.create_new_contact(text, tags, user_id)
    
    if success:
        # Always update the user's recent tags when creating a contact
        db.connect()
        try:
            if tags:
                db.update_user_recent_tags(user_id, tags)
            
            return jsonify({
                "success": True,
                "message": message,
                "user_id": new_user_id
            }), 201
        finally:
            db.disconnect()
    else:
        return jsonify({
            "success": False,
            "message": message
        }), 400

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user_by_id(user_id):
    """Get a specific user by ID."""
    # Check if this request is from a current user viewing a contact
    viewing_user_id = request.args.get('viewing_user_id')
    
    db.connect()
    try:
        user = db.get_user_by_id(user_id)
        if user:
            # If a viewing_user_id was provided and it's different from the user being viewed,
            # update the last_viewed timestamp for the connection
            if viewing_user_id and int(viewing_user_id) != user_id:
                db.update_last_viewed(int(viewing_user_id), user_id)
                
            return jsonify(user)
        return jsonify({"error": "User not found"}), 404
    finally:
        db.disconnect()

@app.route('/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Update an existing user in the database."""
    user_data = request.json
    
    if not user_data:
        return jsonify({"error": "No data provided"}), 400
        
    db.connect()
    try:
        success = db.update_user(user_id, user_data)
        if success:
            return jsonify({"success": True})
        return jsonify({"error": "Failed to update user"}), 400
    finally:
        db.disconnect()

@app.route('/users/search', methods=['GET'])
def search_users():
    """Search for users by name, location, or other attributes."""
    search_term = request.args.get('term', '')
    db.connect()
    try:
        users = db.search_users(search_term)
        return jsonify(users)
    finally:
        db.disconnect()

@app.route('/users/<username>', methods=['GET'])
def get_user(username):
    """Get a specific user by username."""
    # Check if this request is from a current user viewing a contact
    viewing_user_id = request.args.get('viewing_user_id')
    
    db.connect()
    try:
        user = db.get_user_by_username(username)
        if user:
            # If a viewing_user_id was provided and it's different from the user being viewed,
            # update the last_viewed timestamp for the connection
            if viewing_user_id and int(viewing_user_id) != user['id']:
                db.update_last_viewed(int(viewing_user_id), user['id'])
                
            return jsonify(user)
        return jsonify({"error": "User not found"}), 404
    finally:
        db.disconnect()

@app.route('/users/<int:user_id>/connections', methods=['GET'])
def get_connections(user_id):
    """Get all connections for a specific user."""
    db.connect()
    try:
        connections = db.get_user_connections(user_id)
        return jsonify(connections)
    finally:
        db.disconnect()

@app.route('/connections', methods=['POST'])
def add_connection():
    """Add a new connection between users."""
    data = request.json
    user_id = data.get('user_id')
    contact_id = data.get('contact_id')
    description = data.get('description', '')
    notes = data.get('notes', None)
    tags = data.get('tags', None)
    
    if not user_id or not contact_id:
        return jsonify({"error": "Missing user_id or contact_id"}), 400
    
    db.connect()
    try:
        success = db.add_connection(user_id, contact_id, description, notes, tags)
        if success:
            return jsonify({"success": True}), 201
        return jsonify({"error": "Failed to add connection"}), 400
    finally:
        db.disconnect()

@app.route('/connections/update', methods=['PUT'])
def update_connection_details():
    """Update a connection with notes, tags, or update last viewed timestamp."""
    data = request.json
    user_id = data.get('user_id')
    contact_id = data.get('contact_id')
    
    if not user_id or not contact_id:
        return jsonify({"error": "Missing user_id or contact_id"}), 400
    
    # Check if we're just updating the last_viewed timestamp
    update_timestamp_only = data.get('update_timestamp_only', False)
    
    db.connect()
    try:
        if update_timestamp_only:
            success = db.update_last_viewed(user_id, contact_id)
        else:
            update_data = {}
            if 'description' in data:
                update_data['relationship_description'] = data['description']
            if 'notes' in data:
                update_data['notes'] = data['notes']
            if 'tags' in data:
                update_data['tags'] = data['tags']
                
            success = db.update_connection(user_id, contact_id, update_data)
            
        if success:
            return jsonify({"success": True})
        return jsonify({"error": "Failed to update connection"}), 400
    finally:
        db.disconnect()

@app.route('/connections', methods=['DELETE'])
def remove_connection():
    """Remove a connection between users."""
    data = request.json
    user_id = data.get('user_id')
    contact_id = data.get('contact_id')
    
    if not user_id or not contact_id:
        return jsonify({"error": "Missing user_id or contact_id"}), 400
    
    db.connect()
    try:
        success = db.remove_connection(user_id, contact_id)
        if success:
            return jsonify({"success": True})
        return jsonify({"error": "Failed to remove connection"}), 400
    finally:
        db.disconnect()

@app.route('/login', methods=['POST'])
def create_login():
    """Create login credentials for a user."""
    data = request.json
    user_id = data.get('user_id')
    passkey = data.get('passkey')
    
    if not all([user_id, passkey]):
        return jsonify({"error": "Missing required fields"}), 400
    
    db.connect()
    try:
        # Check if user already has login credentials
        has_login = db.user_has_login(user_id)
        if has_login:
            return jsonify({"error": "User already has login credentials"}), 400
            
        # Get the user to generate a username
        user = db.get_user_by_id(user_id)
        if not user:
            return jsonify({"error": "User not found"}), 404
            
        # Create username from first_name and last_name (lowercase with no spaces)
        first_name = user.get('first_name', '')
        last_name = user.get('last_name', '')
        
        if not first_name or not last_name:
            return jsonify({"error": "User must have first and last name to create login"}), 400
        
        # Try to create a unique username
        attempts = 0
        max_attempts = 10
        username_base = (first_name + last_name).lower().replace(' ', '')
        username = username_base
        
        while attempts < max_attempts:
            # Try to add user login with current username
            try:
                success = db.add_user_login(user_id, username, passkey)
                if success:
                    return jsonify({
                        "success": True,
                        "username": username
                    }), 201
            except Exception as e:
                if "duplicate key value" in str(e) and "logins_username_key" in str(e):
                    # Username already exists, try adding a random number
                    username = f"{username_base}{random.randint(1, 100)}"
                    attempts += 1
                else:
                    # Different error
                    raise e
        
        # If we reach here, we couldn't generate a unique username
        return jsonify({"error": "Could not generate a unique username"}), 400
    except Exception as e:
        print(f"Error creating login: {e}")
        return jsonify({"error": "Failed to create login"}), 400
    finally:
        db.disconnect()

@app.route('/login/validate', methods=['POST'])
def validate_login():
    """Validate user login credentials."""
    data = request.json
    username = data.get('username')
    passkey = data.get('passkey')
    
    if not all([username, passkey]):
        return jsonify({"error": "Missing username or passkey"}), 400
    
    db.connect()
    try:
        user_id = db.validate_login(username, passkey)
        if user_id:
            return jsonify({"user_id": user_id})
        return jsonify({"error": "Invalid login credentials"}), 401
    finally:
        db.disconnect()

@app.route('/users/<int:user_id>/recent-tags', methods=['GET'])
def get_user_recent_tags(user_id):
    """Get a user's recently used tags."""
    db.connect()
    try:
        recent_tags = db.get_user_recent_tags(user_id)
        return jsonify(recent_tags)
    finally:
        db.disconnect()

@app.route('/login/update', methods=['POST'])
def update_last_login():
    """Update the last_login timestamp for a logged-in user."""
    data = request.json
    user_id = data.get('user_id')
    
    if not user_id:
        return jsonify({"error": "User ID is required"}), 400
    
    db.connect()
    try:
        # Check if this user has login credentials
        has_login = db.user_has_login(user_id)
        if not has_login:
            return jsonify({"error": "User has no login credentials"}), 404
            
        success = db.update_last_login(user_id)
        if success:
            return jsonify({"success": True})
        return jsonify({"error": "Failed to update last login timestamp"}), 400
    finally:
        db.disconnect()

if __name__ == '__main__':
    app.run(host=API_HOST, port=API_PORT, debug=API_DEBUG) 