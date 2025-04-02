"""
Test script for running the newUser module against sample data from test_samples.json.
This script tests how well the OpenAI model extracts information from different text inputs.

Run this script with:
python test_newUser_samples.py
"""

import os
import json
import time
from typing import Dict, List, Optional
from unittest.mock import patch
import unittest

# Import the necessary functions from newUser
from newUser import process_contact_text, USER_FIELDS
from config import DEFAULT_TAGS

class TestWithSampleData(unittest.TestCase):
    """Test the newUser module with sample data from a JSON file."""
    
    @classmethod
    def setUpClass(cls):
        """Load the sample data from the JSON file."""
        try:
            with open(os.path.join(os.path.dirname(__file__), 'test_samples.json'), 'r') as f:
                cls.test_data = json.load(f)
                cls.samples = cls.test_data.get('samples', [])
                
            if not cls.samples:
                raise ValueError("No samples found in test_samples.json")
                
            print(f"Loaded {len(cls.samples)} test samples")
        except Exception as e:
            print(f"Error loading test samples: {e}")
            cls.samples = []
    
    def _normalize_value(self, value):
        """
        Normalize value for flexible comparison:
        - Convert to lowercase
        - Replace commas and 'and' with spaces
        - Remove extra whitespace
        - Strip punctuation
        """
        if value is None:
            return None
        
        value = str(value).lower()
        # Replace commas and 'and' with spaces for normalization
        value = value.replace(',', ' ').replace(' and ', ' ')
        # Remove extra whitespace and normalize spaces
        value = ' '.join(value.split())
        # Remove common punctuation that might affect comparison
        for char in '.,;:()[]{}':
            value = value.replace(char, '')
        return value
    
    def _values_match(self, expected, actual):
        """
        Check if the expected value matches the actual value using flexible matching.
        This handles cases where formatting differs (commas vs 'and', etc).
        
        Returns True if all expected terms are present in the actual value.
        """
        if actual is None:
            return False
            
        norm_expected = self._normalize_value(expected)
        norm_actual = self._normalize_value(actual)
        
        # If it's a simple exact match after normalization
        if norm_expected == norm_actual:
            return True
        
        # Check if all normalized expected terms are in the normalized actual value
        expected_terms = set(norm_expected.split())
        actual_terms = set(norm_actual.split())
        
        # If all expected terms are contained in the actual terms
        return expected_terms.issubset(actual_terms)
    
    def test_samples_using_api(self):
        """
        Test the OpenAI extraction against each sample in test_samples.json.
        This uses the actual API, so an API key is required.
        
        Set USE_REAL_API=true environment variable to run these tests against the real API.
        """
        if os.getenv('USE_REAL_API') != 'true':
            self.skipTest("Skipping API tests. Set USE_REAL_API=true to run against the real API.")
            return
            
        print("\nRunning tests against the real OpenAI API:")
        results = []
        
        for i, sample in enumerate(self.samples):
            description = sample.get('description', f"Sample {i+1}")
            text = sample.get('text', "")
            should_fail = sample.get('should_fail', False)
            expected_fields = sample.get('expected_fields', {})
            
            print(f"\nTesting: {description}")
            print(f"Input: {text[:50]}..." if len(text) > 50 else f"Input: {text}")
            
            # Process the text
            success, extracted_data, message = process_contact_text(text, [], current_user_id=1)
            
            # Sleep briefly to avoid rate limiting
            time.sleep(1.5)
            
            # Check if the extraction succeeded or failed as expected
            if should_fail:
                if success:
                    print(f"❌ Expected failure but extraction succeeded")
                    results.append({
                        "description": description,
                        "status": "Failed - Should have failed but succeeded",
                        "extracted": extracted_data
                    })
                else:
                    print(f"✅ Expected extraction to fail and it did: {message}")
                    results.append({
                        "description": description,
                        "status": "Passed - Failed as expected",
                        "message": message
                    })
                continue
            
            if not success:
                print(f"❌ Extraction failed unexpectedly: {message}")
                results.append({
                    "description": description,
                    "status": "Failed - Unexpected extraction failure",
                    "message": message
                })
                continue
            
            # Check that expected fields are present and match with flexible comparison
            all_fields_match = True
            field_misses = []
            
            for field, expected_value in expected_fields.items():
                if field not in extracted_data or extracted_data[field] is None:
                    print(f"❌ Field '{field}' is missing or null")
                    field_misses.append(field)
                    all_fields_match = False
                elif not self._values_match(expected_value, extracted_data[field]):
                    print(f"❌ Field '{field}' mismatch: Expected '{expected_value}', got '{extracted_data[field]}'")
                    field_misses.append(field)
                    all_fields_match = False
                else:
                    print(f"✓ Field '{field}' matches")
            
            if all_fields_match:
                print(f"✅ All expected fields found and matched")
                results.append({
                    "description": description,
                    "status": "Passed",
                    "extracted": extracted_data
                })
            else:
                print(f"❌ Some fields did not match or were missing: {', '.join(field_misses)}")
                results.append({
                    "description": description,
                    "status": "Failed - Field mismatch",
                    "missing_or_mismatched": field_misses,
                    "extracted": extracted_data
                })
        
        # Summarize results
        total = len(results)
        passed = sum(1 for r in results if r['status'].startswith('Passed'))
        
        print(f"\n===== SUMMARY =====")
        print(f"Total samples: {total}")
        print(f"Passed: {passed} ({passed/total*100:.1f}%)")
        print(f"Failed: {total - passed} ({(total - passed)/total*100:.1f}%)")
        
        # Save detailed results to a file if requested
        if os.getenv('SAVE_RESULTS') == 'true':
            result_file = os.path.join(os.path.dirname(__file__), 'test_results.json')
            with open(result_file, 'w') as f:
                json.dump({
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "total": total,
                    "passed": passed,
                    "results": results
                }, f, indent=2)
            print(f"Detailed results saved to {result_file}")
    
    def test_samples_with_mocked_api(self):
        """
        Test the process_contact_text function with mocked API responses.
        This doesn't use the real API, so it's faster and doesn't require an API key.
        """
        print("\nRunning tests with mocked API responses:")
        
        for i, sample in enumerate(self.samples):
            description = sample.get('description', f"Sample {i+1}")
            text = sample.get('text', "")
            should_fail = sample.get('should_fail', False)
            expected_fields = sample.get('expected_fields', {})
            
            print(f"\nTesting: {description}")
            
            with patch('openai.ChatCompletion.create') as mock_api:
                # For samples that should fail with missing last_name
                if should_fail and 'last_name' not in expected_fields:
                    # Create a mock response with missing last name
                    mock_api.return_value.choices = [
                        unittest.mock.MagicMock(
                            message=unittest.mock.MagicMock(
                                content=json.dumps(expected_fields)
                            )
                        )
                    ]
                    
                    success, data, message = process_contact_text(text, [], current_user_id=1)
                    self.assertFalse(success, f"Sample '{description}' should have failed but succeeded")
                    continue
                
                # For all other samples, create a mock response with the expected fields
                # Plus other USER_FIELDS as None
                mock_response = {}
                for field in USER_FIELDS:
                    if field in expected_fields:
                        mock_response[field] = expected_fields[field]
                    else:
                        mock_response[field] = None
                
                # Ensure first_name and last_name are present for samples that should succeed
                if not should_fail:
                    if 'first_name' not in mock_response or mock_response['first_name'] is None:
                        mock_response['first_name'] = "Default"
                    if 'last_name' not in mock_response or mock_response['last_name'] is None:
                        mock_response['last_name'] = "Name"
                
                mock_api.return_value.choices = [
                    unittest.mock.MagicMock(
                        message=unittest.mock.MagicMock(
                            content=json.dumps(mock_response)
                        )
                    )
                ]
                
                success, data, message = process_contact_text(text, [], current_user_id=1)
                
                if should_fail:
                    self.assertFalse(success, f"Sample '{description}' should have failed but succeeded")
                else:
                    self.assertTrue(success, f"Sample '{description}' failed unexpectedly: {message}")
                    
                    # Verify expected fields are in the extracted data with flexible comparison
                    for field, expected_value in expected_fields.items():
                        self.assertIn(field, data, f"Field '{field}' missing in extracted data")
                        if data[field] is not None:
                            self.assertTrue(
                                self._values_match(expected_value, data[field]),
                                f"Field '{field}' mismatch: Expected '{expected_value}', got '{data[field]}'"
                            )
            
            print(f"✅ {description}")
        
        print("\nAll mock tests completed successfully!")

if __name__ == '__main__':
    unittest.main() 