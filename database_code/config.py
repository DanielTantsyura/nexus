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

# Database connection URL (default is PostgreSQL on localhost)
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/nexus")

# ==========================================================================
# API SETTINGS
# ==========================================================================

# API host and port configuration
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8080"))

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
DEFAULT_TAGS = "friend,work,family,school,important"

# Maximum number of recent tags to store per user
MAX_RECENT_TAGS = 20 