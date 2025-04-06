"""
Creates the database schema for the Nexus application.

This module contains functions to create the database schema with tables for:
- users: Store user profiles and personal information
- logins: Store login credentials and authentication data
- relationships: Store bidirectional connections between users

The schema supports both one-way and two-way relationship properties, where:
- relationship_description is bidirectional (shared in both directions)
- custom_note, tags, and last_viewed are unidirectional (specific to each direction)
"""

import psycopg2
import os
import sys
from dotenv import load_dotenv

# Add parent directory to the path so we can import from the parent directory
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import DATABASE_URL

# Load environment variables
load_dotenv()

# SQL commands to create database schema
SQL_COMMANDS = """
-- Drop existing tables if they exist
DROP TABLE IF EXISTS relationships;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS users;

-- Create users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone_number VARCHAR(20),
    location VARCHAR(100),
    university VARCHAR(100),
    field_of_interest VARCHAR(200),
    high_school VARCHAR(100),
    gender VARCHAR(50),
    ethnicity VARCHAR(50),
    uni_major VARCHAR(100),
    job_title VARCHAR(100),
    current_company VARCHAR(100),
    profile_image_url VARCHAR(200),
    linkedin_url VARCHAR(200),
    recent_tags TEXT
);

-- Create logins table for authentication
CREATE TABLE logins (
    id SERIAL PRIMARY KEY,
    people_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(50) NOT NULL,
    passkey VARCHAR(100) NOT NULL,
    last_login TIMESTAMP,
    CONSTRAINT unique_people_id UNIQUE (people_id)
);

-- Create relationships table 
-- NOTE: 
-- - relationship_description is bidirectional (shared in both directions)
-- - custom_note, tags, and last_viewed are unidirectional (specific to each direction)
CREATE TABLE relationships (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_description VARCHAR(50) NOT NULL,
    custom_note TEXT,
    tags TEXT,
    last_viewed TIMESTAMP,
    CONSTRAINT unique_relationship UNIQUE (user_id, contact_id)
);
"""

def create_database(connection_string: str = DATABASE_URL) -> bool:
    """
    Create the database schema by executing SQL commands.
    
    Args:
        connection_string: PostgreSQL connection string
        
    Returns:
        True if successful, False otherwise
    """
    conn = None
    try:
        print("Connecting to PostgreSQL database...")
        conn = psycopg2.connect(connection_string)
        cursor = conn.cursor()
        
        print("Creating database schema...")
        cursor.execute(SQL_COMMANDS)
        
        # Commit the changes
        conn.commit()
        
        print("Database schema created successfully.")
        return True
        
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"Error creating database schema: {error}")
        if conn:
            conn.rollback()
        return False
        
    finally:
        if conn:
            cursor.close()
            conn.close()
            print("Database connection closed.")

if __name__ == "__main__":
    # Create the database schema
    success = create_database()
    
    if success:
        print("Database setup completed successfully.")
    else:
        print("Database setup failed.")