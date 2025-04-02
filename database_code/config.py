"""
Configuration settings for the Nexus application.
This module provides hardcoded configuration values for the application.
"""

# Database connection settings
DATABASE_URL = "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"

# API server settings
API_HOST = "0.0.0.0"
API_PORT = 8080
API_DEBUG = True

# iOS app network settings
IOS_SIMULATOR_URL = "http://127.0.0.1:8080"
IOS_DEVICE_URL = "http://10.0.0.232:8080"

# User tag settings
DEFAULT_TAGS = "Entrepreneurship,Finance,Student,Close Friend,Recently Met"
MAX_RECENT_TAGS = 6

# OpenAI model to use
OPENAI_MODEL = "gpt-4o-mini" 