# nexus
Network Tracker For the Elites


## Database Setup Script

The `createDatabase.py` script initializes the PostgreSQL database with the necessary schema for the Nexus application. This script:

1. Connects to a PostgreSQL database hosted on Railway
2. Creates a `users` table that stores:
   - Basic user information (name, username)
   - Professional details (university, field of interest, current company)
   - Location and personal information

3. Creates a `relationships` table that tracks connections between users with:
   - References to both users in the relationship
   - Description of how they are connected
   - Timestamp of when the connection was established

## Getting Started

### Prerequisites
- Python 3.x
- PostgreSQL database (this project uses Railway)
- `psycopg2-binary` package

### Installation

1. Clone this repository
2. Create a virtual environment:
   ```
   python3 -m venv venv
   source venv/bin/activate
   ```
3. Install dependencies:
   ```
   pip install psycopg2-binary
   ```
4. Run the database initialization script:
   ```
   python createDatabase.py
   ```

## Security Note

The connection string in the script contains sensitive database credentials. In a production environment, these should be stored in environment variables or a secure configuration file rather than being hardcoded in the script.