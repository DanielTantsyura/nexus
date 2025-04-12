import psycopg2
import os
import sys

# Add parent directory to path to access config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import DATABASE_URL

# Define your SQL commands
sql_commands = """
-- Drop existing tables (if they exist) to ensure schema updates
DROP TABLE IF EXISTS relationships;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS people;

-- Create the expanded people table
CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    
    -- Identity information
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    
    -- Contact information
    email VARCHAR(100),
    phone_number VARCHAR(20),
    
    -- Personal information
    gender VARCHAR(50),
    ethnicity VARCHAR(100),
    birthday VARCHAR(100),
    location VARCHAR(100),
    
    -- Educational information
    high_school VARCHAR(100),
    university VARCHAR(100),
    uni_major VARCHAR(100),
    
    -- Professional information
    job_title VARCHAR(100),
    current_company VARCHAR(100),
    interests VARCHAR(100),
    
    -- External links
    profile_image_url VARCHAR(255),
    linkedin_url VARCHAR(255),
    
    -- Tags
    recent_tags TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the login table
CREATE TABLE logins (
    id SERIAL PRIMARY KEY,
    
    -- User relationship
    people_id INT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    
    -- Authentication information
    username VARCHAR(50) NOT NULL UNIQUE,
    passkey VARCHAR(100) NOT NULL,
    
    -- Metadata
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the relationships table
CREATE TABLE relationships (
    id SERIAL PRIMARY KEY,
    
    -- User relationships
    user_id INT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    contact_id INT NOT NULL REFERENCES people(id) ON DELETE CASCADE,
    
    -- Relationship description
    relationship_description VARCHAR(255),
    notes TEXT,
    tags TEXT,
    what_they_are_working_on TEXT,
    
    -- Metadata
    last_viewed TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    -- Constraints
    UNIQUE (user_id, contact_id)
);
"""

def create_database():
    """Creates the database schema for the Nexus application."""
    try:
        # Connect to your Railway Postgres instance
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()

        # Execute SQL commands; note that execute() might not handle multiple statements in one call
        # So we split on semicolons and run each one separately
        for command in sql_commands.strip().split(';'):
            if command.strip():
                cursor.execute(command)
        
        conn.commit()
        print("Tables dropped and recreated successfully with updated schema.")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        return False

if __name__ == "__main__":
    create_database()