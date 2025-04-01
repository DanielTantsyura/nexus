#!/usr/bin/env python
"""
Setup script for initializing the Nexus database.

This script provides a comprehensive setup process for the Nexus application:
1. Creates the database schema (tables for users, logins, relationships)
2. Inserts sample users if requested
3. Creates initial relationships between sample users
4. Sets up login credentials for all users

WARNING: Running this script will drop and recreate all tables,
resulting in the loss of all existing data!
"""

import sys
import os
import time
from dotenv import load_dotenv
from config import DATABASE_URL, DEFAULT_TAGS
from createDatabase import create_database
from database_operations import DatabaseManager
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
        print("\n[Step 1/4] Creating database schema...")
        if not create_database(DATABASE_URL):
            print("❌ Database schema creation failed. Aborting setup.")
            return False
        print("✅ Database schema created successfully")
        
        # If no sample data is requested, finish here
        if not include_sample_data:
            print("\nSetup completed without sample data.")
            return True
        
        # Step 2: Insert sample users
        print("\n[Step 2/4] Inserting sample users...")
        sample_users = insert_sample_users()
        if not sample_users:
            print("❌ Failed to insert sample users. Aborting setup.")
            return False
        print(f"✅ {len(sample_users)} sample users inserted successfully")
        
        # Step 3: Insert sample relationships
        print("\n[Step 3/4] Creating sample relationships...")
        if not insert_sample_relationships(sample_users):
            print("❌ Failed to create sample relationships. Continuing anyway...")
        else:
            print("✅ Sample relationships created successfully")
        
        # Step 4: Set up login credentials
        print("\n[Step 4/4] Setting up login credentials...")
        with DatabaseManager(DATABASE_URL) as db:
            if not db.update_passwords(password):
                print("❌ Failed to set up login credentials. Continuing anyway...")
            else:
                print(f"✅ Login credentials set up with password: '{password}'")
        
        # Verify the setup was successful
        print("\nVerifying database setup...")
        with DatabaseManager(DATABASE_URL) as db:
            db.check_database()
        
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