"""
Configuration settings for the Nexus application.
This module loads environment variables and provides default values for application settings.
"""

import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Database connection settings
# Format: postgresql://username:password@host:port/database
DATABASE_URL = os.environ.get(
    "DATABASE_URL", 
    "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"
)

# API server settings
API_HOST = os.environ.get("API_HOST", "0.0.0.0")
API_PORT = int(os.environ.get("API_PORT", "8080"))
API_DEBUG = os.environ.get("API_DEBUG", "True").lower() in ("true", "1", "t")

# iOS app network settings
# These are used in the iOS app's NetworkManager.swift
IOS_SIMULATOR_URL = os.environ.get("IOS_SIMULATOR_URL", "http://127.0.0.1:8080")
IOS_DEVICE_URL = os.environ.get("IOS_DEVICE_URL", "http://10.0.0.232:8080")

# User tag settings
# Default tags are comma-separated and used when creating new contacts
DEFAULT_TAGS = os.environ.get(
    "DEFAULT_TAGS", 
    "Entrepreneurship,Finance,Physicality,Student,Close Friend,Recently Met"
)
# Maximum number of recent tags to store per user
MAX_RECENT_TAGS = int(os.environ.get("MAX_RECENT_TAGS", "6"))

# OpenAI API configuration
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4o-mini") 