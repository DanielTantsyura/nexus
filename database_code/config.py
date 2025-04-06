import os
"""
Configuration settings for the Nexus application.
This module provides configuration values from environment variables with fallbacks.
"""

# Determine if we're running in Railway
IS_RAILWAY = os.environ.get("RAILWAY_ENVIRONMENT") is not None

# Database connection settings
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway")

# API server settings
API_HOST = os.getenv("API_HOST", "0.0.0.0")
# Railway provides PORT environment variable
API_PORT = int(os.getenv("PORT", os.getenv("API_PORT", 8080)))

# Debug mode for development (default to False in production)
API_DEBUG = os.getenv("API_DEBUG", "False").lower() in ("true", "1", "t")

# iOS app network settings - in Railway, we use the Railway domain
if IS_RAILWAY:
    railway_domain = os.environ.get("RAILWAY_PUBLIC_DOMAIN", "your-app.up.railway.app")
    API_BASE_URL = f"https://{railway_domain}"
    IOS_SIMULATOR_URL = API_BASE_URL
    IOS_DEVICE_URL = API_BASE_URL
else:
    # Local development settings
    API_BASE_URL = f"http://localhost:{API_PORT}"
    IOS_SIMULATOR_URL = os.getenv("IOS_SIMULATOR_URL", f"http://127.0.0.1:{API_PORT}")
    IOS_DEVICE_URL = os.getenv("IOS_DEVICE_URL", f"http://10.0.0.232:{API_PORT}")

# User tag settings
DEFAULT_TAGS = os.getenv("DEFAULT_TAGS", "Entrepreneurship,Finance,Student,Close Friend,Recently Met")
MAX_RECENT_TAGS = int(os.getenv("MAX_RECENT_TAGS", "6"))

# OpenAI model and API key settings
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")
# If OpenAI API key is missing, set this flag to disable OpenAI features
OPENAI_AVAILABLE = os.getenv("OPENAI_API_KEY") is not None 