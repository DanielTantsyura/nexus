import psycopg2

# Replace with your Railway connection string
conn_str = "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"

# Define your SQL commands
sql_commands = """
-- Create the expanded users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birthday DATE,
    location VARCHAR(100),
    university VARCHAR(100),
    field_of_interest VARCHAR(100),
    current_company VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create the relationships table
CREATE TABLE IF NOT EXISTS relationships (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship_description VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE (user_id, contact_id)
);
"""

try:
    # Connect to your Railway Postgres instance
    conn = psycopg2.connect(conn_str)
    cursor = conn.cursor()

    # Execute SQL commands; note that execute() might not handle multiple statements in one call
    # So we split on semicolons and run each one separately
    for command in sql_commands.strip().split(';'):
        if command.strip():
            cursor.execute(command)
    
    conn.commit()
    print("Tables created successfully.")

    cursor.close()
    conn.close()
except Exception as e:
    print("An error occurred:", e)