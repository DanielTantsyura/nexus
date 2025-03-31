from flask import Flask, jsonify, request
from database_operations import DatabaseManager
from flask_cors import CORS
from config import API_HOST, API_PORT, API_DEBUG

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
    
    db.connect()
    try:
        user_id = db.add_user(user_data)
        return jsonify({"id": user_id}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.disconnect()

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user_by_id(user_id):
    """Get a specific user by ID."""
    db.connect()
    try:
        user = db.get_user_by_id(user_id)
        if user:
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
    db.connect()
    try:
        user = db.get_user_by_username(username)
        if user:
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
    custom_note = data.get('custom_note', None)
    tags = data.get('tags', None)
    
    if not user_id or not contact_id:
        return jsonify({"error": "Missing user_id or contact_id"}), 400
    
    db.connect()
    try:
        success = db.add_connection(user_id, contact_id, description, custom_note, tags)
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
            if 'custom_note' in data:
                update_data['custom_note'] = data['custom_note']
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
    username = data.get('username')
    passkey = data.get('passkey')
    
    if not all([user_id, username, passkey]):
        return jsonify({"error": "Missing required fields"}), 400
    
    db.connect()
    try:
        success = db.add_user_login(user_id, username, passkey)
        if success:
            return jsonify({"success": True}), 201
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

if __name__ == '__main__':
    app.run(host=API_HOST, port=API_PORT, debug=API_DEBUG) 