# Nexus Database and API

This directory contains the backend components of the Nexus application, including the database schema, API endpoints, and natural language processing for contact creation.

## Core Components

### Database Structure

The system uses PostgreSQL with three main tables:

- **users**: Stores comprehensive user/contact profiles
- **logins**: Manages authentication credentials
- **relationships**: Tracks connections between users with custom metadata

Key updates:
- Email addresses are no longer required to be unique, allowing multiple users with the same email
- Simplified login credential generation using first and last names

### API Server

The Flask-based API (`api.py`) provides endpoints for:

- User management (create, read, update)
- Connection management
- Contact creation from natural language
- Authentication
- Database utilities
- Tag operations for categorizing and filtering connections

### Natural Language Processing

The `newContact.py` module uses OpenAI's GPT-4o-mini to:
- Extract structured information from free-form text descriptions of contacts
- Generate intelligent relationship descriptions based on user profiles and tags
- Provide robust fallbacks when AI services are unavailable
- Process and handle tags for improved relationship context

This enables users to easily add new contacts by simply describing them, while also getting meaningful relationship descriptions.

## Directory Structure

- **api.py**: Flask server with REST endpoints
- **database_operations.py**: Core database access layer with CRUD operations
- **database_utils.py**: Helper functions for database access
- **config.py**: Configuration settings and environment variables
- **newContact.py**: OpenAI integration for text processing
- **setupFiles/**: Database setup and initialization scripts
  - **createDatabase.py**: Schema creation script
  - **insertSampleUsers.py**: Sample user data script
  - **insertSampleRelationships.py**: Sample relationships script
  - **setup.py**: Unified setup script
- **testFiles/**: Test suite for various components
  - **test_api.py**: API endpoint tests
  - **test_database.py**: Database operations tests
  - **test_newContact.py**: NLP processing tests
  - **test_newContact_samples.py**: Sample-based NLP tests
  - **test_samples.json**: Test data for NLP tests

## Data Flow

1. Client application sends a request to `api.py`
2. `newContact.py` processes text using OpenAI's API
3. `database_operations.py` performs CRUD operations
4. Results are returned to the client

## Login Generation

The system now features a simplified login credential creation process:
1. Usernames are automatically generated from a user's first and last name (lowercase, no spaces)
2. If a username already exists, a random number (1-100) is appended to create a unique username
3. This process repeats until a unique username is found or maximum attempts are reached
4. The `/login` endpoint handles this process transparently, returning the generated username

## Setup Instructions

### Prerequisites

- Python 3.9+
- PostgreSQL 13+
- OpenAI API key (for natural language processing)
- Flask and other dependencies (`pip install -r requirements.txt`)

### Configuration

Create a `.env` file with:

```
DATABASE_URL=postgresql://username:password@localhost:5432/nexus
API_PORT=8080
OPENAI_API_KEY=your_openai_api_key
```

### Database Initialization

To initialize the database with schema and sample data:

```bash
python -m setupFiles.setup
```

This script will:
1. Create tables (dropping existing ones)
2. Insert sample users
3. Insert sample relationships
4. Configure default passwords

### Running the API

```bash
python api.py
```

By default, the API runs on localhost:8080.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/people` | GET | List all users |
| `/people` | POST | Create a new user |
| `/people/<int:user_id>` | GET | Get user by ID |
| `/people/<int:user_id>` | PUT | Update a user |
| `/people/search` | GET | Search for users |
| `/people/<int:user_id>/connections` | GET | Get user connections |
| `/connections` | POST | Create a new connection |
| `/connections/update` | PUT | Update a connection |
| `/contacts/create` | POST | Create a contact from text |
| `/login` | POST | Create login credentials with auto-generated username |
| `/login/validate` | POST | Validate login credentials |
| `/login/update` | POST | Update last login timestamp |

## Natural Language Contact Creation

The system can process text descriptions like:

```
"Daniel Tantsyura from Carnegie Mellon University, interested in real estate and entrepreneurship"
```

And extract structured data including:
- First and last name
- University
- Fields of interest
- Other inferred information

The system also generates relationship descriptions (like "University Friend" or "Industry Peer") using:
- The current user's profile information
- The contact's description 
- Any tags provided for the relationship

This makes it easy for users to add contacts in a natural way without filling out forms, while also getting meaningful categorization of relationships.

## Error Handling

The API implements standardized error responses:
- 400: Bad Request (validation errors)
- 404: Not Found (resource doesn't exist)
- 500: Server Error (unexpected failures)

Each error response includes an error message and appropriate HTTP status code.

## Testing

Run the test suite with:

```bash
python -m unittest discover -s testFiles
```

To run specific test modules:

```bash
python -m unittest testFiles.test_api
python -m unittest testFiles.test_database
python -m unittest testFiles.test_newContact
```

These tests cover all major API functionality including:
- User operations
- Connection management
- Authentication
- Natural language processing 