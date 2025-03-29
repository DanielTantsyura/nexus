import requests
import json
import time

# Base URL for API
BASE_URL = "http://localhost:8080"

def test_get_all_users():
    """Test the GET /users endpoint"""
    print("\n--- Testing GET /users ---")
    response = requests.get(f"{BASE_URL}/users")
    if response.status_code == 200:
        users = response.json()
        print(f"Success! Found {len(users)} users")
        if users:
            print(f"Sample user: {users[0]['first_name']} {users[0]['last_name']}")
        return users
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return []

def test_search_users(term):
    """Test the GET /users/search endpoint"""
    print(f"\n--- Testing GET /users/search?term={term} ---")
    response = requests.get(f"{BASE_URL}/users/search", params={"term": term})
    if response.status_code == 200:
        users = response.json()
        print(f"Success! Found {len(users)} users matching '{term}'")
        for user in users:
            print(f"- {user['first_name']} {user['last_name']} ({user['location']})")
        return users
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return []

def test_get_user_by_username(username):
    """Test the GET /users/<username> endpoint"""
    print(f"\n--- Testing GET /users/{username} ---")
    response = requests.get(f"{BASE_URL}/users/{username}")
    if response.status_code == 200:
        user = response.json()
        print(f"Success! Found user: {user['first_name']} {user['last_name']}")
        print(f"Email: {user['email']}")
        print(f"University: {user['university']}")
        return user
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return None

def test_get_connections(user_id):
    """Test the GET /users/<user_id>/connections endpoint"""
    print(f"\n--- Testing GET /users/{user_id}/connections ---")
    response = requests.get(f"{BASE_URL}/users/{user_id}/connections")
    if response.status_code == 200:
        connections = response.json()
        print(f"Success! Found {len(connections)} connections for user ID {user_id}")
        for conn in connections:
            print(f"- {conn['first_name']} {conn['last_name']} - {conn['relationship_description']}")
        return connections
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return []

def test_add_user(user_data):
    """Test the POST /users endpoint"""
    print("\n--- Testing POST /users ---")
    response = requests.post(f"{BASE_URL}/users", json=user_data)
    if response.status_code == 201:
        result = response.json()
        print(f"Success! Added user with ID: {result['id']}")
        return result['id']
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return None

def test_update_user(user_id, user_data):
    """Test the PUT /users/<user_id> endpoint"""
    print(f"\n--- Testing PUT /users/{user_id} ---")
    response = requests.put(f"{BASE_URL}/users/{user_id}", json=user_data)
    if response.status_code == 200:
        print(f"Success! Updated user with ID: {user_id}")
        return True
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return False

def test_add_connection(user_id, contact_id, description):
    """Test the POST /connections endpoint"""
    print(f"\n--- Testing POST /connections ---")
    data = {
        "user_id": user_id,
        "contact_id": contact_id,
        "description": description
    }
    response = requests.post(f"{BASE_URL}/connections", json=data)
    if response.status_code == 201:
        print(f"Success! Added connection between user {user_id} and {contact_id}")
        return True
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return False

def test_remove_connection(user_id, contact_id):
    """Test the DELETE /connections endpoint"""
    print(f"\n--- Testing DELETE /connections ---")
    data = {
        "user_id": user_id,
        "contact_id": contact_id
    }
    response = requests.delete(f"{BASE_URL}/connections", json=data)
    if response.status_code == 200:
        print(f"Success! Removed connection between user {user_id} and {contact_id}")
        return True
    else:
        print(f"Failed with status code: {response.status_code}")
        print(response.text)
        return False

def run_all_tests():
    print("=== Starting API Tests ===")
    
    # Test 1: Get all users
    users = test_get_all_users()
    
    if users:
        # Store some user IDs for later tests
        existing_user_id = users[0]['id']
        
        # Test 2: Search for users
        test_search_users("New York")
        
        # Test 3: Get user by username
        username = users[0]['username']
        test_get_user_by_username(username)
        
        # Test 4: Get user connections
        connections = test_get_connections(existing_user_id)
        
        # Test 5: Add a new test user
        new_user_data = {
            "username": f"testuser_{int(time.time())}",
            "first_name": "Test",
            "last_name": "User",
            "email": f"test.user{int(time.time())}@example.com",
            "phone_number": "5551234567",
            "location": "Test Location",
            "university": "Test University",
            "field_of_interest": "Testing",
            "high_school": "Test High School"
        }
        new_user_id = test_add_user(new_user_data)
        
        if new_user_id:
            # Test 6: Update the user we just created
            update_data = {
                "location": "Updated Location",
                "field_of_interest": "Updated Interest"
            }
            test_update_user(new_user_id, update_data)
            
            # Test 7: Add a connection between users
            if len(users) > 1:
                second_user_id = users[1]['id']
                test_add_connection(existing_user_id, new_user_id, "Test connection")
                
                # Test 8: Remove the connection we just created
                test_remove_connection(existing_user_id, new_user_id)
    
    print("\n=== API Tests Completed ===")

if __name__ == "__main__":
    run_all_tests() 