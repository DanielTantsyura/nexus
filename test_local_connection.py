import requests
import sys
import json

def test_api_connection():
    """Test if we can connect to the API from the local machine"""
    base_url = "http://localhost:8080"
    
    try:
        # Test the users endpoint
        print(f"Testing connection to {base_url}/users...")
        response = requests.get(f"{base_url}/users")
        
        if response.status_code == 200:
            users = response.json()
            print(f"Connection successful! Found {len(users)} users.\n")
            
            # Print sample user data
            if users:
                print("Sample user data:")
                user = users[0]
                print(f"Name: {user['first_name']} {user['last_name']}")
                print(f"Username: {user['username']}")
                print(f"Email: {user['email']}")
                print(f"University: {user['university']}")
                
            return True
        else:
            print(f"Connection failed with status code: {response.status_code}")
            print(response.text)
            return False
            
    except Exception as e:
        print(f"Error connecting to API: {e}")
        return False

if __name__ == "__main__":
    success = test_api_connection()
    sys.exit(0 if success else 1) 