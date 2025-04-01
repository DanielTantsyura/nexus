"""
Insert sample users into the Nexus database for testing and demonstration.

This module provides a function to populate the database with sample user profiles
for testing purposes. It creates diverse user profiles with various fields populated
to demonstrate the application's functionality.
"""

import json
import os
from typing import List, Dict, Any, Optional
from database_operations import DatabaseManager
from config import DATABASE_URL, DEFAULT_TAGS

def insert_sample_users() -> Optional[List[Dict[str, Any]]]:
    """
    Insert sample users into the database.
    
    Returns:
        List of dictionaries containing user data if successful, None otherwise
    """
    # Sample user data
    users = [
        {
            "username": "johndoe",
            "first_name": "John",
            "last_name": "Doe",
            "email": "john.doe@example.com",
            "phone_number": "555-123-4567",
            "location": "New York, NY",
            "university": "Stanford University",
            "field_of_interest": "Computer Science, Artificial Intelligence",
            "high_school": "Brooklyn Tech High School",
            "gender": "Male",
            "ethnicity": "White",
            "uni_major": "Computer Science",
            "job_title": "Software Engineer",
            "current_company": "Google",
            "profile_image_url": "https://randomuser.me/api/portraits/men/1.jpg",
            "linkedin_url": "https://linkedin.com/in/johndoe",
            "recent_tags": DEFAULT_TAGS
        },
        {
            "username": "janedoe",
            "first_name": "Jane",
            "last_name": "Doe",
            "email": "jane.doe@example.com",
            "phone_number": "555-987-6543",
            "location": "San Francisco, CA",
            "university": "UC Berkeley",
            "field_of_interest": "Data Science, Machine Learning",
            "high_school": "Mission High School",
            "gender": "Female",
            "ethnicity": "Asian",
            "uni_major": "Statistics",
            "job_title": "Data Scientist",
            "current_company": "Meta",
            "profile_image_url": "https://randomuser.me/api/portraits/women/1.jpg",
            "linkedin_url": "https://linkedin.com/in/janedoe",
            "recent_tags": DEFAULT_TAGS
        },
        {
            "username": "msmith",
            "first_name": "Michael",
            "last_name": "Smith",
            "email": "michael.smith@example.com",
            "phone_number": "555-456-7890",
            "location": "Chicago, IL",
            "university": "University of Chicago",
            "field_of_interest": "Finance, Economics",
            "high_school": "Whitney M. Young Magnet High School",
            "gender": "Male",
            "ethnicity": "Black",
            "uni_major": "Economics",
            "job_title": "Financial Analyst",
            "current_company": "Goldman Sachs",
            "profile_image_url": "https://randomuser.me/api/portraits/men/2.jpg",
            "linkedin_url": "https://linkedin.com/in/michaelsmith",
            "recent_tags": DEFAULT_TAGS
        },
        {
            "username": "ejohnson",
            "first_name": "Emily",
            "last_name": "Johnson",
            "email": "emily.johnson@example.com",
            "phone_number": "555-789-0123",
            "location": "Boston, MA",
            "university": "Harvard University",
            "field_of_interest": "Medicine, Research",
            "high_school": "Boston Latin School",
            "gender": "Female",
            "ethnicity": "White",
            "uni_major": "Biology",
            "job_title": "Medical Researcher",
            "current_company": "Massachusetts General Hospital",
            "profile_image_url": "https://randomuser.me/api/portraits/women/2.jpg",
            "linkedin_url": "https://linkedin.com/in/emilyjohnson",
            "recent_tags": DEFAULT_TAGS
        },
        {
            "username": "dwilliams",
            "first_name": "David",
            "last_name": "Williams",
            "email": "david.williams@example.com",
            "phone_number": "555-234-5678",
            "location": "Seattle, WA",
            "university": "University of Washington",
            "field_of_interest": "Engineering, Robotics",
            "high_school": "Roosevelt High School",
            "gender": "Male",
            "ethnicity": "Hispanic",
            "uni_major": "Mechanical Engineering",
            "job_title": "Robotics Engineer",
            "current_company": "Amazon",
            "profile_image_url": "https://randomuser.me/api/portraits/men/3.jpg",
            "linkedin_url": "https://linkedin.com/in/davidwilliams",
            "recent_tags": DEFAULT_TAGS
        }
    ]
    
    # Insert users into the database
    try:
        print(f"Inserting {len(users)} sample users...")
        with DatabaseManager(DATABASE_URL) as db:
            for user in users:
                user_id = db.add_user(user)
                print(f"Added user: {user['first_name']} {user['last_name']} (ID: {user_id})")
                
                # Set up login credentials for each user
                db.add_user_login(user_id, user['username'], "password")
        
        return users
    except Exception as e:
        print(f"Error inserting sample users: {e}")
        return None

if __name__ == "__main__":
    # When run directly, insert sample users
    result = insert_sample_users()
    if result:
        print(f"Successfully inserted {len(result)} sample users")
    else:
        print("Failed to insert sample users")
