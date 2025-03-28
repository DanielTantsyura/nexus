"""
Unified setup script for the Nexus application.

This script:
1. Creates the database schema
2. Inserts sample users
3. Inserts sample relationships
"""

from createDatabase import create_database
from insertSampleUsers import insert_sample_users
from insertSampleRelationships import insert_sample_relationships

def setup_database():
    """Set up the database with schema and sample data."""
    print("\n=== Setting up Nexus Database ===\n")
    
    print("Step 1: Creating database schema...")
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
    
    print("\n=== Database setup completed successfully! ===\n")
    print("You can now run the API with: python api.py")
    return True

if __name__ == "__main__":
    setup_database() 