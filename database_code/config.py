import os
"""
Configuration settings for the Nexus application.
This module provides configuration values from environment variables with fallbacks.
"""

# Database connection settings
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway")

# API server settings
API_HOST = os.getenv("API_HOST", "0.0.0.0")
# Railway provides PORT environment variable
API_PORT = int(os.getenv("PORT", os.getenv("API_PORT", 8080)))

# Debug mode for development (default to False in production)
API_DEBUG = os.getenv("API_DEBUG", "False").lower() in ("true", "1", "t")

# iOS app network settings
IOS_SIMULATOR_URL = os.getenv("IOS_SIMULATOR_URL", "http://127.0.0.1:8080")
IOS_DEVICE_URL = os.getenv("IOS_DEVICE_URL", "http://10.0.0.232:8080")

# User tag settings
DEFAULT_TAGS = os.getenv("DEFAULT_TAGS", "Entrepreneurship,Finance,Student,Close Friend,Recently Met")
MAX_RECENT_TAGS = int(os.getenv("MAX_RECENT_TAGS", "6"))

# OpenAI model to use
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini") 