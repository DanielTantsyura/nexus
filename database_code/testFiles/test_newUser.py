"""
Test suite for the newUser module.

This module tests various aspects of the newUser.py functionality, including:
1. Field extraction from plain text using OpenAI API
2. Handling of edge cases and invalid inputs
3. Error conditions and fallbacks
4. Integration with the database API

To run these tests:
python -m unittest test_newUser.py
"""

import unittest
import json
import os
import sys
from unittest.mock import patch, MagicMock
from typing import Dict, List

# Add parent directory to path to access required modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from newUser import process_contact_text, create_new_contact, get_user_fields_from_schema, USER_FIELDS
from config import DEFAULT_TAGS

class TestUserFieldsExtraction(unittest.TestCase):
    """Test the extraction of user fields from the database schema."""
    
    def test_user_fields_extraction(self):
        """Test that user fields are correctly extracted from createDatabase.py."""
        fields = get_user_fields_from_schema()
        
        # Check that we have fields
        self.assertTrue(len(fields) > 0)
        
        # Check that required fields exist
        required_fields = ["first_name", "last_name", "email", "phone_number"]
        for field in required_fields:
            self.assertIn(field, fields)
        
        # Check that system fields are excluded
        excluded_fields = ["id", "created_at"]
        for field in excluded_fields:
            self.assertNotIn(field, fields)
        
        # Verify consistency with USER_FIELDS global
        self.assertEqual(fields, USER_FIELDS)

class TestProcessContactText(unittest.TestCase):
    """Test the processing of free-form text into structured user data."""
    
    @patch('openai.ChatCompletion.create')
    def test_basic_extraction(self, mock_openai):
        """Test basic extraction of user data from text."""
        # Mock OpenAI API response
        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps({
                "first_name": "John",
                "last_name": "Doe",
                "email": "john.doe@example.com",
                "phone_number": "123-456-7890",
                "job_title": "Software Engineer",
                "current_company": "Google"
            })))
        ]
        mock_openai.return_value = mock_response
        
        # Test text
        text = "John Doe is a Software Engineer at Google. Email: john.doe@example.com, Phone: 123-456-7890"
        tags = ["tech", "friend"]
        
        success, data, message = process_contact_text(text, tags, current_user_id=1)
        
        # Assertions
        self.assertTrue(success)
        self.assertEqual("John", data["first_name"])
        self.assertEqual("Doe", data["last_name"])
        self.assertEqual("john.doe@example.com", data["email"])
        self.assertEqual("123-456-7890", data["phone_number"])
        self.assertEqual("Software Engineer", data["job_title"])
        self.assertEqual("Google", data["current_company"])
        self.assertEqual(DEFAULT_TAGS, data["recent_tags"])
    
    @patch('openai.ChatCompletion.create')
    def test_complex_extraction(self, mock_openai):
        """Test extraction of multiple fields from complex text."""
        # Mock OpenAI API response
        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps({
                "first_name": "Jane",
                "last_name": "Smith",
                "email": "jane.smith@apple.com",
                "phone_number": "415-555-1234",
                "location": "Cupertino, CA",
                "university": "Stanford",
                "field_of_interest": "AI, Product Management",
                "uni_major": "Computer Science",
                "job_title": "Product Manager",
                "current_company": "Apple",
                "birthday": "1990-05-15"
            })))
        ]
        mock_openai.return_value = mock_response
        
        # Test text with more complex information
        text = """
        Jane Smith is a Product Manager at Apple who graduated from Stanford with a CS degree in 2012.
        She's interested in AI and Product Management. Her email is jane.smith@apple.com and phone is 415-555-1234.
        Jane lives in Cupertino, CA and was born on May 15, 1990.
        """
        tags = ["tech", "product", "AI"]
        
        success, data, message = process_contact_text(text, tags, current_user_id=1)
        
        # Assertions
        self.assertTrue(success)
        self.assertEqual("Jane", data["first_name"])
        self.assertEqual("Smith", data["last_name"])
        self.assertEqual("jane.smith@apple.com", data["email"])
        self.assertEqual("Stanford", data["university"])
        self.assertEqual("Computer Science", data["uni_major"])
        self.assertEqual("1990-05-15", data["birthday"])
        self.assertEqual(DEFAULT_TAGS, data["recent_tags"])
    
    @patch('openai.ChatCompletion.create')
    def test_missing_required_fields(self, mock_openai):
        """Test handling of missing required fields."""
        # Mock OpenAI API response with missing last name
        mock_response = MagicMock()
        mock_response.choices = [
            MagicMock(message=MagicMock(content=json.dumps({
                "first_name": "John",
                "last_name": None,
                "email": "john@example.com"
            })))
        ]
        mock_openai.return_value = mock_response
        
        text = "John works at Google"
        tags = ["work"]
        
        success, data, message = process_contact_text(text, tags, current_user_id=1)
        
        # Should fail because last_name is missing/null
        self.assertFalse(success)
        self.assertIsNone(data)
        self.assertIn("name", message.lower())
    
    def test_empty_text(self):
        """Test handling of empty or very short text."""
        # Empty text
        success, data, message = process_contact_text("", [], current_user_id=1)
        self.assertFalse(success)
        self.assertIsNone(data)
        
        # Too short text
        success, data, message = process_contact_text("Hi", [], current_user_id=1)
        self.assertFalse(success)
        self.assertIsNone(data)
    
    @patch('openai.ChatCompletion.create')
    def test_api_failure_fallback(self, mock_openai):
        """Test fallback mechanism when OpenAI API call fails."""
        # Mock OpenAI API to raise an exception
        mock_openai.side_effect = Exception("API Error")
        
        text = "John Doe is a developer"
        tags = ["tech"]
        
        success, data, message = process_contact_text(text, tags, current_user_id=1)
        
        # Should fall back to basic extraction
        self.assertTrue(success)
        self.assertEqual("John", data["first_name"])
        self.assertEqual("Doe", data["last_name"])
        self.assertIn("API", message)
        self.assertEqual(DEFAULT_TAGS, data["recent_tags"])

class TestCreateNewContact(unittest.TestCase):
    """Test the creation of new contacts from processed text."""
    
    @patch('newUser.process_contact_text')
    @patch('newUser.requests.post')
    def test_successful_contact_creation(self, mock_post, mock_process):
        """Test successful creation of a new contact."""
        # Mock the process_contact_text function
        mock_process.return_value = (True, {
            "first_name": "John",
            "last_name": "Doe",
            "email": "john.doe@example.com",
            "recent_tags": DEFAULT_TAGS
        }, "Success")
        
        # Mock the API responses
        mock_user_response = MagicMock()
        mock_user_response.status_code = 201
        mock_user_response.json.return_value = {"id": 123}
        
        mock_rel_response = MagicMock()
        mock_rel_response.status_code = 201
        
        # Configure the mock to return different responses for different URLs
        def mock_post_side_effect(url, **kwargs):
            if "users" in url:
                return mock_user_response
            elif "connections" in url:
                return mock_rel_response
        
        mock_post.side_effect = mock_post_side_effect
        
        # Test the function
        text = "John Doe is a developer"
        tags = ["tech", "friend"]
        current_user_id = 1
        
        success, message, user_id = create_new_contact(text, tags, current_user_id)
        
        # Assertions
        self.assertTrue(success)
        self.assertEqual(123, user_id)
        self.assertIn("success", message.lower())
        
        # Verify API calls
        self.assertEqual(2, mock_post.call_count)
    
    @patch('newUser.process_contact_text')
    def test_processing_failure(self, mock_process):
        """Test handling of text processing failures."""
        # Mock the process_contact_text function to return failure
        mock_process.return_value = (False, None, "Could not process text")
        
        text = "Invalid text"
        tags = []
        current_user_id = 1
        
        success, message, user_id = create_new_contact(text, tags, current_user_id)
        
        # Assertions
        self.assertFalse(success)
        self.assertIsNone(user_id)
        self.assertEqual("Could not process text", message)
    
    @patch('newUser.process_contact_text')
    @patch('newUser.requests.post')
    def test_user_creation_api_failure(self, mock_post, mock_process):
        """Test handling of user creation API failures."""
        # Mock the process_contact_text function
        mock_process.return_value = (True, {
            "first_name": "John",
            "last_name": "Doe"
        }, "Success")
        
        # Mock the API response to indicate failure
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.json.return_value = {"error": "Validation failed"}
        mock_post.return_value = mock_response
        
        text = "John Doe is a developer"
        tags = ["tech"]
        current_user_id = 1
        
        success, message, user_id = create_new_contact(text, tags, current_user_id)
        
        # Assertions
        self.assertFalse(success)
        self.assertIsNone(user_id)
        self.assertIn("Validation failed", message)
    
    @patch('newUser.process_contact_text')
    @patch('newUser.requests.post')
    def test_relationship_creation_api_failure(self, mock_post, mock_process):
        """Test handling of relationship creation API failures."""
        # Mock the process_contact_text function
        mock_process.return_value = (True, {
            "first_name": "John",
            "last_name": "Doe"
        }, "Success")
        
        # Mock the user API response
        mock_user_response = MagicMock()
        mock_user_response.status_code = 201
        mock_user_response.json.return_value = {"id": 123}
        
        # Mock the relationship API response to indicate failure
        mock_rel_response = MagicMock()
        mock_rel_response.status_code = 400
        mock_rel_response.json.return_value = {"error": "Relationship already exists"}
        
        # Configure the mock to return different responses for different URLs
        def mock_post_side_effect(url, **kwargs):
            if "users" in url:
                return mock_user_response
            elif "connections" in url:
                return mock_rel_response
        
        mock_post.side_effect = mock_post_side_effect
        
        text = "John Doe is a developer"
        tags = ["tech"]
        current_user_id = 1
        
        success, message, user_id = create_new_contact(text, tags, current_user_id)
        
        # Assertions
        self.assertFalse(success)
        self.assertEqual(123, user_id)  # Should still have the user ID
        self.assertIn("Relationship already exists", message)

class TestEndToEnd(unittest.TestCase):
    """
    End-to-end tests using the API.
    Note: These tests require the API to be running.
    Set RUN_END_TO_END_TESTS environment variable to 'true' to run these tests.
    """
    
    @unittest.skipIf(os.getenv('RUN_END_TO_END_TESTS') != 'true', 
                     "End-to-end tests skipped. Set RUN_END_TO_END_TESTS=true to run.")
    def test_full_contact_creation_flow(self):
        """Test the full flow of creating a contact through the API."""
        # This test will make real API calls to OpenAI and your local API server
        text = """
        Alice Johnson is a data scientist at Microsoft. She graduated from UC Berkeley with a
        Ph.D. in Statistics in 2018. Her email is alice.j@example.com and phone is 510-555-9876.
        She lives in Seattle, WA and specializes in machine learning algorithms.
        """
        tags = ["tech", "data science", "machine learning"]
        current_user_id = 1  # Assumes user with ID 1 exists
        
        success, message, user_id = create_new_contact(text, tags, current_user_id)
        
        # Assertions
        self.assertTrue(success)
        self.assertIsNotNone(user_id)
        self.assertIn("success", message.lower())

if __name__ == '__main__':
    unittest.main() 