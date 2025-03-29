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
    
    if not user_id or not contact_id:
        return jsonify({"error": "Missing user_id or contact_id"}), 400
    
    db.connect()
    try:
        success = db.add_connection(user_id, contact_id, description)
        if success:
            return jsonify({"success": True}), 201
        return jsonify({"error": "Failed to add connection"}), 400
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

if __name__ == '__main__':
    app.run(host=API_HOST, port=API_PORT, debug=API_DEBUG) 