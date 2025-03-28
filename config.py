"""
Configuration settings for the Nexus application.
"""

import os

# Database connection settings
# In production, use environment variables for credentials
DATABASE_URL = os.environ.get(
    "DATABASE_URL", 
    "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"
)

# API settings
API_HOST = "0.0.0.0"
API_PORT = 8080
API_DEBUG = True

# iOS app settings
IOS_SIMULATOR_URL = "http://127.0.0.1:8080"
IOS_DEVICE_URL = "http://10.0.0.232:8080"  # Replace with your actual IP as needed 