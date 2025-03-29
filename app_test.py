#!/usr/bin/env python
"""
Comprehensive test for the Nexus application.

This script:
1. Verifies the database is properly set up
2. Tests all API endpoints for correct functionality
3. Validates data consistency across operations
"""

import requests
import json
import time
import sys
from pprint import pprint

# Configuration
API_URL = "http://localhost:8080"
VERBOSE = True

def log(message):
    """Print a message if verbose mode is enabled"""
    if VERBOSE:
        print(message)

def test_api_connection():
    """Test basic API connectivity"""
    log("\n=== Testing API Connection ===")
    
    try:
        response = requests.get(f"{API_URL}/users")
        if response.status_code == 200:
            log("✅ API is running and accessible")
            return True
        else:
            log(f"❌ API returned status code {response.status_code}")
            return False
    except Exception as e:
        log(f"❌ Failed to connect to API: {e}")
        return False

def test_user_operations():
    """Test user CRUD operations"""
    log("\n=== Testing User Operations ===")
    
    # Step 1: Get all users
    log("\n--- Step 1: Get all users ---")
    response = requests.get(f"{API_URL}/users")
    if response.status_code != 200:
        log(f"❌ Failed to get users. Status code: {response.status_code}")
        return False
    
    users = response.json()
    log(f"Found {len(users)} users in the database")
    if len(users) < 5:
        log("❌ Expected at least 5 sample users")
        return False
    log("✅ Users retrieved successfully")
    
    # Step 2: Create a new test user
    log("\n--- Step 2: Create a new test user ---")
    test_user_data = {
        "username": f"testuser_{int(time.time())}",
        "first_name": "Test",
        "last_name": "User",
        "email": f"test.user{int(time.time())}@example.com",
        "phone_number": "5551234567",
        "location": "Test Location",
        "university": "Test University",
        "field_of_interest": "Comprehensive Testing",
        "high_school": "Test High School"
    }
    
    response = requests.post(f"{API_URL}/users", json=test_user_data)
    if response.status_code != 201:
        log(f"❌ Failed to create user. Status code: {response.status_code}")
        return False
    
    user_id = response.json().get('id')
    if not user_id:
        log("❌ No user ID returned from create operation")
        return False
    log(f"✅ Created test user with ID: {user_id}")
    
    # Step 3: Update test user
    log("\n--- Step 3: Update test user ---")
    update_data = {
        "location": "Updated Test Location",
        "field_of_interest": "Updated Testing, Software Quality"
    }
    
    response = requests.put(f"{API_URL}/users/{user_id}", json=update_data)
    if response.status_code != 200:
        log(f"❌ Failed to update user. Status code: {response.status_code}")
        return False
    log("✅ Updated test user successfully")
    
    # Step 4: Search for users
    log("\n--- Step 4: Search for users ---")
    search_term = "Test"
    response = requests.get(f"{API_URL}/users/search?term={search_term}")
    if response.status_code != 200:
        log(f"❌ Failed to search users. Status code: {response.status_code}")
        return False
    
    search_results = response.json()
    if not any(user.get('first_name') == 'Test' for user in search_results):
        log("❌ Test user not found in search results")
        return False
    log(f"✅ Search found {len(search_results)} users matching '{search_term}'")
    
    # Success
    return True

def test_connection_operations():
    """Test connection operations between users"""
    log("\n=== Testing Connection Operations ===")
    
    # Step 1: Get users for connecting
    log("\n--- Step 1: Get users for connection test ---")
    response = requests.get(f"{API_URL}/users")
    if response.status_code != 200:
        log(f"❌ Failed to get users. Status code: {response.status_code}")
        return False
    
    users = response.json()
    if len(users) < 2:
        log("❌ Need at least 2 users for connection test")
        return False
    
    user1_id = users[0]['id']
    user2_id = users[1]['id']
    log(f"Using users with IDs {user1_id} and {user2_id} for connection test")
    
    # Step 2: Create connection
    log("\n--- Step 2: Create connection ---")
    connection_data = {
        "user_id": user1_id,
        "contact_id": user2_id,
        "description": "Test connection from comprehensive test"
    }
    
    response = requests.post(f"{API_URL}/connections", json=connection_data)
    if response.status_code != 201:
        log(f"❌ Failed to create connection. Status code: {response.status_code}")
        return False
    log("✅ Created test connection successfully")
    
    # Step 3: Get user connections
    log("\n--- Step 3: Get user connections ---")
    response = requests.get(f"{API_URL}/users/{user1_id}/connections")
    if response.status_code != 200:
        log(f"❌ Failed to get connections. Status code: {response.status_code}")
        return False
    
    connections = response.json()
    log(f"User has {len(connections)} connections")
    
    # Verify our connection exists
    connection_exists = False
    for connection in connections:
        if connection.get('id') == user2_id:
            connection_exists = True
            break
    
    if not connection_exists:
        log("❌ Created connection not found in user's connections")
        return False
    log("✅ Connection verification successful")
    
    # Step 4: Remove connection
    log("\n--- Step 4: Remove connection ---")
    connection_data = {
        "user_id": user1_id,
        "contact_id": user2_id
    }
    
    response = requests.delete(f"{API_URL}/connections", json=connection_data)
    if response.status_code != 200:
        log(f"❌ Failed to remove connection. Status code: {response.status_code}")
        return False
    log("✅ Removed test connection successfully")
    
    # Success
    return True

def run_all_tests():
    """Run all application tests"""
    log("\n🔍 Starting Nexus Application Test Suite 🔍\n")
    
    # Test API connection
    if not test_api_connection():
        log("\n❌ API connection test failed. Aborting further tests.")
        return False
    
    # Test user operations
    if not test_user_operations():
        log("\n❌ User operations test failed.")
        return False
    
    # Test connection operations
    if not test_connection_operations():
        log("\n❌ Connection operations test failed.")
        return False
    
    # All tests passed
    log("\n✅ All tests passed! The Nexus application is working correctly.")
    return True

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1) 