#!/usr/bin/env python
"""
Setup script for initializing the Nexus database.

This script provides a comprehensive setup process for the Nexus application:
1. Creates the database schema (tables for users, logins, relationships)
2. Inserts sample users if requested
3. Creates initial relationships between sample users

WARNING: Running this script will drop and recreate all tables,
resulting in the loss of all existing data!
"""

import sys
import os
import time
import psycopg2
from dotenv import load_dotenv

# Add parent directory to the path so we can import from the parent directory
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import DATABASE_URL

# Import local modules
from createDatabase import create_database
from insertSampleUsers import insert_sample_users
from insertSampleRelationships import insert_sample_relationships

# Load environment variables
load_dotenv()

def setup_database(include_sample_data: bool = True, password: str = "password") -> bool:
    """
    Set up the Nexus database with schema and optional sample data.
    
    Args:
        include_sample_data: Whether to include sample users and relationships
        password: Default password to set for all users
        
    Returns:
        True if setup was successful, False otherwise
    """
    try:
        print("\n===== NEXUS DATABASE SETUP =====")
        print("WARNING: This will drop and recreate all tables!")
        
        # Step 1: Create database schema
        print("\n[Step 1/3] Creating database schema...")
        if not create_database(DATABASE_URL):
            print("❌ Database schema creation failed. Aborting setup.")
            return False
        print("✅ Database schema created successfully")
        
        # If no sample data is requested, finish here
        if not include_sample_data:
            print("\nSetup completed without sample data.")
            return True
        
        # Step 2: Insert sample users
        print("\n[Step 2/3] Inserting sample users...")
        if not insert_sample_users():
            print("❌ Failed to insert sample users. Aborting setup.")
            return False
        print("✅ Sample users inserted successfully")
        
        # Step 3: Insert sample relationships
        print("\n[Step 3/3] Creating sample relationships...")
        if not insert_sample_relationships():
            print("❌ Failed to create sample relationships. Continuing anyway...")
        else:
            print("✅ Sample relationships created successfully")
        
        # Set up login credentials
        print("\nSetting up login credentials...")
        try:
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # Get all users
            cursor.execute("SELECT id, username FROM users WHERE username IS NOT NULL")
            users = cursor.fetchall()
            
            # Create login entries for each user
            for user_id, username in users:
                # Check if login already exists
                cursor.execute("SELECT id FROM logins WHERE people_id = %s", (user_id,))
                login = cursor.fetchone()
                
                if login:
                    # Update existing login
                    cursor.execute(
                        "UPDATE logins SET passkey = %s WHERE people_id = %s",
                        (password, user_id)
                    )
                else:
                    # Create new login
                    cursor.execute(
                        "INSERT INTO logins (people_id, username, passkey) VALUES (%s, %s, %s)",
                        (user_id, username, password)
                    )
            
            conn.commit()
            print(f"✅ Login credentials set up with password: '{password}'")
            
            cursor.close()
            conn.close()
        except Exception as e:
            print(f"❌ Failed to set up login credentials: {e}")
        
        # Verify the setup was successful
        print("\nVerifying database setup...")
        try:
            conn = psycopg2.connect(DATABASE_URL)
            cursor = conn.cursor()
            
            # Count users
            cursor.execute("SELECT COUNT(*) FROM users")
            user_count = cursor.fetchone()[0]
            
            # Count relationships
            cursor.execute("SELECT COUNT(*) FROM relationships")
            relationship_count = cursor.fetchone()[0]
            
            # Count logins
            cursor.execute("SELECT COUNT(*) FROM logins")
            login_count = cursor.fetchone()[0]
            
            print(f"Database contains: {user_count} users, {relationship_count} relationships, {login_count} login credentials")
            
            cursor.close()
            conn.close()
        except Exception as e:
            print(f"Error verifying database: {e}")
        
        print("\n===== SETUP COMPLETED SUCCESSFULLY =====")
        print(f"Sample data was {'included' if include_sample_data else 'not included'}")
        print(f"Default password for all users: '{password}'")
        
        return True
        
    except Exception as e:
        print(f"\n❌ ERROR: Database setup failed: {str(e)}")
        return False

if __name__ == "__main__":
    # Parse command line arguments
    include_samples = True
    password = "password"
    
    # Check for --no-samples flag
    if "--no-samples" in sys.argv:
        include_samples = False
    
    # Check for --password argument
    for i, arg in enumerate(sys.argv):
        if arg == "--password" and i+1 < len(sys.argv):
            password = sys.argv[i+1]
    
    # Run the setup
    success = setup_database(include_sample_data=include_samples, password=password)
    
    if not success:
        print("\nDatabase setup failed. See errors above.")
        sys.exit(1)
    
    print("\nDatabase is ready to use!")
    sys.exit(0)