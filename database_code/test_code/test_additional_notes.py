"""
Test the additional notes extraction from contact text in the newUser module.
"""

import os
import sys
import json
from dotenv import load_dotenv

# Add the parent directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database_code.newUser import process_contact_text

# Load environment variables
load_dotenv()

def test_additional_notes_extraction():
    """
    Test the extraction of additional notes from contact text.
    """
    test_cases = [
        {
            "description": "Basic contact with additional notes",
            "text": "John Smith is a software engineer at Google. He's working on a secret project that he can't talk about. We met at a hackathon in 2022 and I found his ideas fascinating. He has a dog named Max and enjoys hiking on weekends.",
            "expected_fields": ["first_name", "last_name", "job_title", "current_company"],
            "expected_additional_notes": True,
        },
        {
            "description": "Contact with personal interests",
            "text": "Jane Doe, Harvard MBA student. She's interested in sustainable business practices and has been volunteering at a local community garden. We connected over coffee last week and she mentioned she's training for a marathon.",
            "expected_fields": ["first_name", "last_name", "university"],
            "expected_additional_notes": True,
        },
        {
            "description": "Contact with meeting context",
            "text": "Michael Johnson from Microsoft. Met him at the AI conference in San Francisco. He gave a presentation on cloud computing that was really insightful. We exchanged business cards and he said he'd be interested in collaborating on a project.",
            "expected_fields": ["first_name", "last_name", "current_company"],
            "expected_additional_notes": True,
        },
        {
            "description": "Professional contact with detailed background",
            "text": "Emily Wilson is a data scientist with a PhD in Statistics from Stanford. She previously worked at Facebook for 5 years. She's an expert in NLP and has published several papers on sentiment analysis. I was introduced to her by a mutual colleague and we discussed potential research collaborations.",
            "expected_fields": ["first_name", "last_name", "university", "field_of_interest"],
            "expected_additional_notes": True,
        },
        {
            "description": "Contact with minimal information",
            "text": "Robert Brown, lawyer",
            "expected_fields": ["first_name", "last_name", "job_title"],
            "expected_additional_notes": False,
        }
    ]

    print("\n=== Testing Additional Notes Extraction ===\n")
    successful_tests = 0

    for idx, test_case in enumerate(test_cases, 1):
        print(f"Test {idx}: {test_case['description']}")
        print(f"Input: {test_case['text'][:80]}..." if len(test_case['text']) > 80 else f"Input: {test_case['text']}")
        
        # Process the text
        success, user_data, message, additional_notes = process_contact_text(
            test_case['text'], [], 1
        )
        
        if not success:
            print(f"❌ Failed to process text: {message}")
            continue
        
        # Check that expected fields are extracted
        fields_present = all(user_data.get(field) for field in test_case['expected_fields'])
        
        if fields_present:
            print("✅ Successfully extracted basic user fields")
            
            # Print extracted fields
            for field in test_case['expected_fields']:
                print(f"  - {field}: {user_data.get(field)}")
        else:
            print("❌ Failed to extract all expected fields")
            for field in test_case['expected_fields']:
                if not user_data.get(field):
                    print(f"  - Missing: {field}")
        
        # Check additional notes
        if test_case['expected_additional_notes'] and additional_notes:
            print("✅ Successfully extracted additional notes:")
            print(f"  {additional_notes[:150]}..." if len(additional_notes) > 150 else f"  {additional_notes}")
            successful_tests += 1
        elif not test_case['expected_additional_notes'] and not additional_notes:
            print("✅ Correctly did not extract additional notes (none expected)")
            successful_tests += 1
        elif test_case['expected_additional_notes'] and not additional_notes:
            print("❌ Failed to extract additional notes when expected")
        else:
            print("❌ Extracted additional notes when none expected")
            print(f"  {additional_notes}")
            
        print("\n" + "-" * 80 + "\n")
    
    print(f"Tests completed: {successful_tests}/{len(test_cases)} successful\n")

if __name__ == "__main__":
    test_additional_notes_extraction() 