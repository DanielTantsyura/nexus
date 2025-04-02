"""
Configuration settings for the Nexus application.

This module contains centralized configuration settings for the Nexus application,
including database connection settings, API configuration, and application defaults.
"""

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# ==========================================================================
# DATABASE SETTINGS
# ==========================================================================

# Database connection settings
# In production, use environment variables for credentials
DATABASE_HOST = "localhost"
DATABASE_NAME = "nexus"
DATABASE_USER = "postgres"  # Update with your database username
DATABASE_PASSWORD = "postgres"  # Update with your database password
DATABASE_PORT = "5432"

# Create a connection string that includes connection pooling settings
DATABASE_URL = os.environ.get(
    "DATABASE_URL", 
    "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"
)

# ==========================================================================
# API SETTINGS
# ==========================================================================

# API host and port configuration
API_HOST = "0.0.0.0"  # Listen on all network interfaces
API_PORT = 8080

# Debug mode for development
API_DEBUG = os.getenv("API_DEBUG", "True").lower() in ("true", "1", "t")

# ==========================================================================
# IOS APP SETTINGS
# ==========================================================================

# URLs for iOS app to connect to the API
IOS_SIMULATOR_URL = f"http://localhost:{API_PORT}"
IOS_DEVICE_URL = os.getenv("IOS_DEVICE_URL", f"http://localhost:{API_PORT}")

# ==========================================================================
# USER TAG SETTINGS
# ==========================================================================

# Default tags for new users/relationships
DEFAULT_TAGS = "family,friend,work,school,neighbor,event"

# Maximum number of recent tags to store per user
MAX_RECENT_TAGS = 10

# Authentication
AUTH_SECRET_KEY = "dev-secret-key-change-in-production"  # Change this in production!
AUTH_TOKEN_EXPIRY = 86400  # 24 hours in seconds

# ==========================================================================
# AI SETTINGS
# ==========================================================================

# OpenAI API configuration
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")  # Default to GPT-4o mini

# Content Generation
DEFAULT_MODELS = [
    "gpt-4o-mini",  # New model
    "gpt-3.5-turbo",
    "gpt-4-turbo",
    "gemini-pro",
    "claude-3-opus"
]

# Sample Connection Types
CONNECTION_TYPES = [
    "Friend",
    "Family",
    "Classmate",
    "Colleague",
    "Mentor",
    "Business Contact",
    "Acquaintance",
    "Neighbor",
    "Other"
] 