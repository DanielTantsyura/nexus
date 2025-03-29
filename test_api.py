#!/usr/bin/env python
"""
Comprehensive test suite for the Nexus API and application.

This script:
1. Verifies API connectivity
2. Tests all API endpoints for correct functionality
3. Validates user operations (search, create, update)
4. Tests connection operations (create, list, delete)
5. Verifies login functionality
6. Runs comprehensive end-to-end tests
"""

import requests
import json
import time
import sys
from pprint import pprint
import argparse

# Configuration
BASE_URL = "http://localhost:8080"
VERBOSE = True

# Test status tracking
test_results = {
    "total": 0,
    "passed": 0,
    "failed": 0
}

def log(message):
    """Print a message if verbose mode is enabled"""
    if VERBOSE:
        print(message)

def increment_test(passed=True):
    """Increment test counter statistics"""
    test_results["total"] += 1
    if passed:
        test_results["passed"] += 1
    else:
        test_results["failed"] += 1

# ====== Basic API Testing Functions ======

def test_get_all_users():
    """Test the GET /users endpoint"""
    log("\n--- Testing GET /users ---")
    response = requests.get(f"{BASE_URL}/users")
    if response.status_code == 200:
        users = response.json()
        log(f"✅ Success! Found {len(users)} users")
        if users:
            log(f"Sample user: {users[0]['first_name']} {users[0]['last_name']}")
        increment_test(True)
        return users
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return []

def test_search_users(term):
    """Test the GET /users/search endpoint"""
    log(f"\n--- Testing GET /users/search?term={term} ---")
    response = requests.get(f"{BASE_URL}/users/search", params={"term": term})
    if response.status_code == 200:
        users = response.json()
        log(f"✅ Success! Found {len(users)} users matching '{term}'")
        for user in users[:3]:  # Limit output to 3 users
            log(f"- {user['first_name']} {user['last_name']} ({user['location']})")
        increment_test(True)
        return users
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return []

def test_get_user_by_username(username):
    """Test the GET /users/<username> endpoint"""
    log(f"\n--- Testing GET /users/{username} ---")
    response = requests.get(f"{BASE_URL}/users/{username}")
    if response.status_code == 200:
        user = response.json()
        log(f"✅ Success! Found user: {user['first_name']} {user['last_name']}")
        log(f"Email: {user['email']}")
        log(f"University: {user['university']}")
        increment_test(True)
        return user
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return None

def test_get_connections(user_id):
    """Test the GET /users/<user_id>/connections endpoint"""
    log(f"\n--- Testing GET /users/{user_id}/connections ---")
    response = requests.get(f"{BASE_URL}/users/{user_id}/connections")
    if response.status_code == 200:
        connections = response.json()
        log(f"✅ Success! Found {len(connections)} connections for user ID {user_id}")
        for conn in connections[:3]:  # Limit output to 3 connections
            log(f"- {conn['first_name']} {conn['last_name']} - {conn.get('relationship_description', 'N/A')}")
        increment_test(True)
        return connections
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return []

def test_add_user(user_data):
    """Test the POST /users endpoint"""
    log("\n--- Testing POST /users ---")
    # Ensure default values for all fields
    required_fields = [
        'gender', 'ethnicity', 'uni_major', 'job_title', 'current_company'
    ]
    for field in required_fields:
        if field not in user_data:
            user_data[field] = f"Test {field.replace('_', ' ').title()}"
        
    response = requests.post(f"{BASE_URL}/users", json=user_data)
    if response.status_code == 201:
        result = response.json()
        log(f"✅ Success! Added user with ID: {result['id']}")
        increment_test(True)
        return result['id']
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return None

def test_update_user(user_id, user_data):
    """Test the PUT /users/<user_id> endpoint"""
    log(f"\n--- Testing PUT /users/{user_id} ---")
    response = requests.put(f"{BASE_URL}/users/{user_id}", json=user_data)
    if response.status_code == 200:
        log(f"✅ Success! Updated user with ID: {user_id}")
        increment_test(True)
        return True
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return False

def test_add_connection(user_id, contact_id, description):
    """Test the POST /connections endpoint"""
    log(f"\n--- Testing POST /connections ---")
    data = {
        "user_id": user_id,
        "contact_id": contact_id,
        "description": description
    }
    response = requests.post(f"{BASE_URL}/connections", json=data)
    if response.status_code == 201:
        log(f"✅ Success! Added connection between user {user_id} and {contact_id}")
        increment_test(True)
        return True
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return False

def test_remove_connection(user_id, contact_id):
    """Test the DELETE /connections endpoint"""
    log(f"\n--- Testing DELETE /connections ---")
    data = {
        "user_id": user_id,
        "contact_id": contact_id
    }
    response = requests.delete(f"{BASE_URL}/connections", json=data)
    if response.status_code == 200:
        log(f"✅ Success! Removed connection between user {user_id} and {contact_id}")
        increment_test(True)
        return True
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return False

def test_create_login(user_id, username, passkey):
    """Test the POST /login endpoint"""
    log(f"\n--- Testing POST /login ---")
    data = {
        'user_id': user_id,
        'username': username,
        'passkey': passkey
    }
    
    response = requests.post(f"{BASE_URL}/login", json=data)
    if response.status_code == 201:
        log(f"✅ Success! Created login for user ID: {user_id}")
        increment_test(True)
        return True
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return False

def test_login_validation(username, passkey):
    """Test the POST /login/validate endpoint"""
    log(f"\n--- Testing POST /login/validate ---")
    data = {
        'username': username,
        'passkey': passkey
    }
    
    response = requests.post(f"{BASE_URL}/login/validate", json=data)
    if response.status_code == 200:
        result = response.json()
        log(f"✅ Success! Validated login for user ID: {result['user_id']}")
        increment_test(True)
        return result['user_id']
    else:
        log(f"❌ Failed with status code: {response.status_code}")
        log(response.text)
        increment_test(False)
        return None

# ====== Comprehensive Test Suites ======

def test_api_connection():
    """Test basic API connectivity"""
    log("\n=== Testing API Connection ===")
    
    try:
        response = requests.get(f"{BASE_URL}/users")
        if response.status_code == 200:
            log("✅ API is running and accessible")
            increment_test(True)
            return True
        else:
            log(f"❌ API returned status code {response.status_code}")
            increment_test(False)
            return False
    except Exception as e:
        log(f"❌ Failed to connect to API: {e}")
        increment_test(False)
        return False

def test_user_operations():
    """Test comprehensive user operations"""
    log("\n=== Testing User Operations ===")
    
    # Create a new test user
    test_user_data = {
        "username": f"testuser_{int(time.time())}",
        "first_name": "Test",
        "last_name": "User",
        "email": f"test.user{int(time.time())}@example.com",
        "phone_number": "5551234567",
        "location": "Test Location",
        "university": "Test University",
        "field_of_interest": "Comprehensive Testing",
        "high_school": "Test High School",
        "gender": "Non-binary",
        "ethnicity": "Mixed",
        "uni_major": "Computer Science",
        "job_title": "QA Engineer",
        "current_company": "Test Corp"
    }
    
    user_id = test_add_user(test_user_data)
    if not user_id:
        return False
    
    # Update the user
    update_data = {
        "location": "Updated Test Location",
        "field_of_interest": "Updated Testing, Software Quality"
    }
    
    if not test_update_user(user_id, update_data):
        return False
    
    # Search for the user
    search_results = test_search_users("Test")
    if not any(user.get('id') == user_id for user in search_results):
        log("❌ Test user not found in search results")
        increment_test(False)
        return False
    
    return True

def test_connection_operations():
    """Test comprehensive connection operations"""
    log("\n=== Testing Connection Operations ===")
    
    # Get users for testing
    users = test_get_all_users()
    if len(users) < 2:
        log("❌ Need at least 2 users for connection test")
        increment_test(False)
        return False
    
    user1_id = users[0]['id']
    user2_id = users[1]['id']
    
    # Create connection
    if not test_add_connection(user1_id, user2_id, "Test connection"):
        return False
    
    # Verify connection exists
    connections = test_get_connections(user1_id)
    connection_exists = any(conn.get('id') == user2_id for conn in connections)
    if not connection_exists:
        log("❌ Created connection not found in user's connections")
        increment_test(False)
        return False
    
    # Check bidirectional connection
    connections = test_get_connections(user2_id)
    connection_exists = any(conn.get('id') == user1_id for conn in connections)
    if not connection_exists:
        log("❌ Bidirectional connection not found")
        increment_test(False)
    else:
        log("✅ Bidirectional connection verified")
        increment_test(True)
    
    # Remove connection
    if not test_remove_connection(user1_id, user2_id):
        return False
    
    # Verify connection is removed
    connections = test_get_connections(user1_id)
    connection_exists = any(conn.get('id') == user2_id for conn in connections)
    if connection_exists:
        log("❌ Connection was not properly removed")
        increment_test(False)
        return False
    
    log("✅ Connection removal verified")
    increment_test(True)
    return True

def test_login_operations():
    """Test comprehensive login operations"""
    log("\n=== Testing Login Operations ===")
    
    # Create a test user with a login
    username = f"logintest_{int(time.time())}"
    passkey = "testpassword123"
    
    test_user_data = {
        "username": username,
        "first_name": "Login",
        "last_name": "Tester",
        "email": f"login.test{int(time.time())}@example.com",
        "phone_number": "5557654321",
        "location": "Login Test Location",
        "university": "Auth University",
        "field_of_interest": "Authentication, Security",
        "high_school": "Security High",
        "gender": "Other",
        "ethnicity": "Test",
        "uni_major": "Authentication Science",
        "job_title": "Security Tester",
        "current_company": "Auth Corp"
    }
    
    user_id = test_add_user(test_user_data)
    if not user_id:
        return False
    
    # Create login credentials
    if not test_create_login(user_id, username, passkey):
        return False
    
    # Validate login with correct credentials
    validated_user_id = test_login_validation(username, passkey)
    if validated_user_id != user_id:
        log("❌ Login validation failed or returned incorrect user ID")
        increment_test(False)
        return False
    
    # Validate login with incorrect credentials
    incorrect_validated_user_id = test_login_validation(username, "wrongpassword")
    if incorrect_validated_user_id is not None:
        log("❌ Login validation succeeded with incorrect password")
        increment_test(False)
        return False
    
    log("✅ Login validation with incorrect password correctly failed")
    increment_test(True)
    return True

def run_basic_tests():
    """Run a set of basic API tests"""
    log("=== Starting Basic API Tests ===")
    
    # Test 1: Get all users
    users = test_get_all_users()
    
    if users:
        # Store some user IDs for later tests
        existing_user_id = users[0]['id']
        
        # Test 2: Search for users
        test_search_users("New York")
        
        # Test 3: Get user by username
        if 'username' in users[0]:
            username = users[0]['username']
            test_get_user_by_username(username)
        
        # Test 4: Get user connections
        test_get_connections(existing_user_id)
        
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
        
        # Test 9: Test login validation
        if username:
            # Use the known passkey format from insertSampleLogins.py
            passkey = "password"  # All real users now have this password
            test_login_validation(username, passkey)
    
    log("\n=== Basic API Tests Completed ===")

def run_comprehensive_tests():
    """Run a more thorough set of tests for all features"""
    log("=== Starting Comprehensive Tests ===")
    
    # Start with basic connectivity test
    if not test_api_connection():
        log("❌ API connectivity failed. Cannot continue tests.")
        return
    
    # Test user operations
    test_user_operations()
    
    # Test connection operations
    test_connection_operations()
    
    # Test login operations
    test_login_operations()
    
    log("\n=== Comprehensive Tests Completed ===")

def display_results():
    """Display test results summary"""
    log("\n=== Test Results Summary ===")
    log(f"Total tests run: {test_results['total']}")
    log(f"Tests passed: {test_results['passed']}")
    log(f"Tests failed: {test_results['failed']}")
    
    if test_results['failed'] == 0:
        log("\n✅ ALL TESTS PASSED")
    else:
        log(f"\n❌ {test_results['failed']} TESTS FAILED")

def main():
    """Main entry point"""
    global VERBOSE
    
    parser = argparse.ArgumentParser(description='Run tests for the Nexus API')
    parser.add_argument('--basic', action='store_true', help='Run basic tests only')
    parser.add_argument('--quick', action='store_true', help='Run quick connectivity test only')
    parser.add_argument('--quiet', action='store_true', help='Suppress detailed output')
    args = parser.parse_args()
    
    if args.quiet:
        VERBOSE = False
    
    if args.quick:
        test_api_connection()
    elif args.basic:
        run_basic_tests()
    else:
        run_comprehensive_tests()
    
    display_results()
    
    # Return non-zero exit code if any tests failed
    return 1 if test_results['failed'] > 0 else 0

if __name__ == "__main__":
    sys.exit(main()) 