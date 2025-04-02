import psycopg2
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Get database URL from environment
DATABASE_URL = os.environ.get(
    "DATABASE_URL", 
    "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"
)

def test_connection():
    """Test the database connection and print status"""
    print(f"Attempting to connect to database...")
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        
        # Create a cursor
        cur = conn.cursor()
        
        # Execute a simple query
        cur.execute("SELECT version();")
        
        # Fetch the result
        version = cur.fetchone()
        print("Successfully connected to the database!")
        print(f"PostgreSQL version: {version[0]}")
        
        # Test querying the logins table
        cur.execute("SELECT COUNT(*) FROM logins;")
        count = cur.fetchone()
        print(f"Number of records in logins table: {count[0]}")
        
        # Close cursor and connection
        cur.close()
        conn.close()
        print("Connection closed successfully")
        
    except Exception as e:
        print(f"Error connecting to database: {str(e)}")

if __name__ == "__main__":
    test_connection() 