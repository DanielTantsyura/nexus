import psycopg2
from config import DATABASE_URL

# Define your SQL commands
sql_commands = """
-- Drop existing tables (if they exist) to ensure schema updates
DROP TABLE IF EXISTS relationships;
DROP TABLE IF EXISTS logins;
DROP TABLE IF EXISTS users;

-- Create the expanded users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone_number VARCHAR(20),
    birthday DATE,
    location VARCHAR(100),
    high_school VARCHAR(100),
    university VARCHAR(100),
    field_of_interest VARCHAR(100),
    current_company VARCHAR(100),
    gender VARCHAR(50),
    ethnicity VARCHAR(100),
    uni_major VARCHAR(100),
    job_title VARCHAR(100),
    profile_image_url VARCHAR(255),
    linkedin_url VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the login table
CREATE TABLE logins (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    username VARCHAR(50) NOT NULL UNIQUE,
    passkey VARCHAR(100) NOT NULL,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the relationships table
CREATE TABLE relationships (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_description VARCHAR(255),
    custom_note TEXT,
    tags TEXT,
    last_viewed TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
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