# Nexus Database Code

This directory contains the database backend code for the Nexus application, a relationship management platform that allows users to create, track, and manage connections.

## Overview

The Nexus database uses PostgreSQL and consists of the following core components:

- Database schema for users, relationships, and authentication
- RESTful API endpoints for interacting with the database
- Utilities for database operations and management
- Test and setup scripts

## Components

### Core Files

- `config.py` - Configuration settings for the database, API, and other components
- `createDatabase.py` - Creates the database schema with tables for users, logins, and relationships
- `database_operations.py` - Core database interaction class with all database operations
- `api.py` - Flask-based RESTful API for accessing the database
- `newUser.py` - Utilities for processing natural language input into structured user data
- `setup.py` - Script to set up the database with schema and optional sample data

### Setup and Sample Data

- `insertSampleUsers.py` - Inserts sample user profiles into the database
- `insertSampleRelationships.py` - Creates sample relationships between users

## Database Schema

The database uses three primary tables:

1. **users** - Stores user profiles with personal information
2. **logins** - Manages authentication credentials and tracks last login timestamps
3. **relationships** - Manages connections between users with the following structure:
   - `relationship_type` is bidirectional (shared in both directions)
   - `note`, `tags`, and `last_viewed` are unidirectional (specific to each direction)

## Getting Started

### Prerequisites

- PostgreSQL database
- Python 3.8+
- Required Python packages (see `requirements.txt`)

### PostgreSQL Setup

1. Install PostgreSQL on your system if not already installed
   - Mac: `brew install postgresql` and `brew services start postgresql`
   - Ubuntu: `sudo apt install postgresql postgresql-contrib`
   - Windows: Download and install from the [PostgreSQL website](https://www.postgresql.org/download/windows/)

2. Create a database for the application:
   ```bash
   sudo -u postgres psql
   CREATE DATABASE nexus;
   CREATE USER nexus_user WITH ENCRYPTED PASSWORD 'your_password';
   GRANT ALL PRIVILEGES ON DATABASE nexus TO nexus_user;
   \q
   ```

### Environment Setup

Create a `.env` file with the following variables:

```
DATABASE_URL=postgresql://username:password@localhost:5432/nexus
API_PORT=8080
OPENAI_API_KEY=your_openai_api_key
```

Ensure your DATABASE_URL points to a valid PostgreSQL instance you have access to.

### Database Setup

To set up the database with schema and sample data:

```bash
python setup.py
```

To set up without sample data:

```bash
python setup.py --no-samples
```

To customize the default password:

```bash
python setup.py --password custompassword
```

### Running the API

To start the API server:

```bash
python api.py
```

By default, the API runs on port 8080, which can be changed in the config.py file or via the API_PORT environment variable.

To run the API on a different port:

```bash
python api.py --port 9000
```

## Using the API

The API provides the following endpoints:

- `/users` - Create and retrieve users
- `/users/<id>` - Get or update a specific user
- `/users/search` - Search for users by name, location, etc.
- `/connections/<user_id>` - Get connections for a specific user
- `/connections` - Create, update, or remove connections between users
- `/contacts/create` - Create a new contact from text
- `/login` - Validate user login credentials and update last login timestamp
- `/users/<id>/update-last-login` - Update last login timestamp when app is opened

## Relationship Management

The relationship system supports both one-way and two-way properties:

- **Two-way properties**: `relationship_type` is shared in both directions
- **One-way properties**: `note`, `tags`, and `last_viewed` are specific to each direction

This design allows users to maintain their own perspective on the relationship while sharing a common relationship type.

## Login Tracking

The system tracks when users log in or open the application:

- The `last_login` field in the `logins` table is automatically updated when:
  - A user successfully logs in through the `/login` endpoint
  - The app is opened and calls the `/users/<id>/update-last-login` endpoint

This tracking enables features like:
- Showing "last seen" information for users
- Detecting inactive accounts
- Providing activity analytics

## Additional Features

- **Natural Language Processing**: The system can extract structured user data from free-form text using OpenAI's API
- **Tag Management**: Users can tag connections and maintain a list of recent tags
- **Password Management**: Utilities for setting and validating login credentials

## Troubleshooting

### PostgreSQL Connection Issues

If you encounter errors connecting to PostgreSQL:

1. **Check PostgreSQL service status**:
   - Mac: `brew services list` to check if PostgreSQL is running
   - Ubuntu: `sudo service postgresql status`
   - Windows: Check Services application

2. **Verify PostgreSQL connection settings**:
   - Ensure the DATABASE_URL in your `.env` file is correct
   - Verify you can connect manually: `psql -U username -d nexus`

3. **PostgreSQL Authentication**:
   - Check if pg_hba.conf is configured to allow local connections
   - Ensure the user has appropriate permissions

4. **Port Conflicts**:
   - Verify PostgreSQL is listening on the expected port (default 5432)
   - Check if another service is using the same port

For more detailed diagnostics, run:
```bash
python -c "import psycopg2; conn = psycopg2.connect('your_connection_string'); print('Connection successful!')"
``` 