# Nexus Database and API

This directory contains the backend components of the Nexus application, including the database schema, API endpoints, and natural language processing for contact creation.

## Core Components

### Database Structure

The system uses PostgreSQL with three main tables:

- **users**: Stores comprehensive user/contact profiles
- **logins**: Manages authentication credentials
- **relationships**: Tracks connections between users with custom metadata

### API Server

The Flask-based API (`api.py`) provides endpoints for:

- User management (create, read, update)
- Connection management
- Contact creation from natural language
- Authentication
- Database utilities

### Natural Language Processing

The `newUser.py` module uses OpenAI's GPT-4o-mini to extract structured information from free-form text descriptions of contacts, enabling users to easily add new contacts by simply describing them.

## Key Files

- **api.py**: Flask server with REST endpoints
- **database_operations.py**: Core database access layer with CRUD operations
- **database_utils.py**: Helper functions for database access
- **createDatabase.py**: Schema creation and initialization
- **config.py**: Configuration settings and environment variables
- **newUser.py**: OpenAI integration for text processing
- **test_api.py**: Comprehensive API tests
- **setup.py**: One-step setup script

## Data Flow

1. API request arrives at a Flask endpoint
2. API layer validates input and prepares parameters
3. Database operations layer executes SQL against PostgreSQL
4. Results are processed and returned as JSON

For contact creation via natural language:
1. Text is sent to the `/contacts/create` endpoint
2. `newUser.py` processes text using OpenAI's API
3. Structured data is extracted and validated
4. User record is created using database operations
5. Relationship is established between the creator and new contact

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

```bash
python createDatabase.py
```

This creates the database schema. To populate it with sample data:

```bash
python insertSampleUsers.py
python insertSampleRelationships.py
```

### Running the API

```bash
python api.py
```

By default, the API runs on localhost:8080.

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/users` | GET | List all users |
| `/users` | POST | Create a new user |
| `/users/<int:user_id>` | GET | Get user by ID |
| `/users/<int:user_id>` | PUT | Update a user |
| `/users/search` | GET | Search for users |
| `/users/<int:user_id>/connections` | GET | Get user connections |
| `/connections` | POST | Create a new connection |
| `/connections/update` | PUT | Update a connection |
| `/contacts/create` | POST | Create a contact from text |
| `/login` | POST | Authenticate user |

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

This makes it easy for users to add contacts in a natural way without filling out forms.

## Error Handling

The API implements standardized error responses:
- 400: Bad Request (validation errors)
- 404: Not Found (resource doesn't exist)
- 500: Server Error (unexpected failures)

Each error response includes an error message and appropriate HTTP status code.

## Testing

Run the comprehensive test suite with:

```bash
python test_api.py
```

This tests all major API functionality including:
- User operations
- Connection management
- Authentication
- Natural language processing 