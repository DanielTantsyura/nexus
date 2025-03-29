from flask import Flask, jsonify, request
from database_operations import DatabaseManager
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable cross-origin requests

# Initialize database connection
db = DatabaseManager()

@app.route('/users', methods=['GET'])
def get_users():
    db.connect()
    try:
        users = db.get_all_users()
        return jsonify(users)
    finally:
        db.disconnect()

@app.route('/users/search', methods=['GET'])
def search_users():
    search_term = request.args.get('term', '')
    db.connect()
    try:
        users = db.search_users(search_term)
        return jsonify(users)
    finally:
        db.disconnect()

@app.route('/users/<username>', methods=['GET'])
def get_user(username):
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
    db.connect()
    try:
        connections = db.get_user_connections(user_id)
        return jsonify(connections)
    finally:
        db.disconnect()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 