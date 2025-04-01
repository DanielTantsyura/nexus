#!/usr/bin/env python
"""
Unified setup script for the Nexus application.

This script:
1. Creates the database schema
2. Inserts sample users
3. Inserts sample relationships
4. Sets up login credentials

WARNING: This script drops and recreates tables, so all existing data will be lost.
Only use this script when setting up the database for the first time or when you're
willing to lose all existing data.
"""

from createDatabase import create_database
from insertSampleUsers import insert_sample_users
from insertSampleRelationships import insert_sample_relationships
from database_utils import DatabaseUtils
import sys
import time

def setup_database():
    """Set up the database with schema and sample data."""
    print("\n=== Setting up Nexus Database ===\n")
    
    print("⚠️ WARNING: This will delete all existing data in the database! ⚠️")
    print("The schema has been updated with new fields for users, relationships, and logins.")
    print("All existing data will be lost.")
    
    print("\nProceeding with database setup in 3 seconds...")
    time.sleep(3)
    
    print("\nStep 1: Creating database schema...")
    if create_database():
        print("✅ Database schema created successfully.\n")
    else:
        print("❌ Failed to create database schema.\n")
        return False
    
    print("Step 2: Inserting sample users...")
    if insert_sample_users():
        print("✅ Sample users inserted successfully.\n")
    else:
        print("❌ Failed to insert sample users.\n")
        return False
    
    print("Step 3: Inserting sample relationships...")
    if insert_sample_relationships():
        print("✅ Sample relationships inserted successfully.\n")
    else:
        print("❌ Failed to insert sample relationships.\n")
        return False
    
    print("Step 4: Setting up user passwords...")
    db_utils = DatabaseUtils()
    try:
        db_utils.update_passwords("password")
        print("✅ User passwords configured successfully.\n")
    except Exception as e:
        print(f"❌ Failed to set up user passwords: {e}\n")
        return False
    
    print("\n=== Database setup completed successfully! ===\n")
    print("You can now run the API with: python api.py")
    print("Default username/password for all users is: <username>/password")
    return True

if __name__ == "__main__":
    setup_database()