import psycopg2
import os
import sys
from datetime import datetime

# Add parent directory to path to access config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import DATABASE_URL, DEFAULT_TAGS

# Sample data as a list of dictionaries
sample_data = [
    {
        "first_name": "Daniel",
        "last_name": "Tantsyura",
        "email": "dan.tantsyura@gmail.com",
        "phone_number": "2033135627",
        "birthday": "04/15/2005",
        "location": "Westchester, New York",
        "university": "CMU",
        "interests": "Business, Investing, Networking, Long Term Success",
        "high_school": "Riverdale",
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Computer Science",
        "job_title": "Product Manager",
        "current_company": "Nexus Inc.",
        "profile_image_url": "https://randomuser.me/api/portraits/men/1.jpg",
        "linkedin_url": "https://linkedin.com/in/danieltantsyura",
        "recent_tags": DEFAULT_TAGS
    },
    {
        "first_name": "Soren",
        "last_name": "Dupont",
        "email": None,
        "phone_number": "6467998920",
        "birthday": "04/15/2005",
        "location": "Brooklyn, New York",
        "university": "CMU",
        "interests": "Libertarian Economics, Math Competitions and Research, Coding",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Mathematics",
        "job_title": "Researcher",
        "current_company": "Tech Innovations",
        "profile_image_url": "https://randomuser.me/api/portraits/men/2.jpg",
        "linkedin_url": "https://linkedin.com/in/sorendupont",
        "recent_tags": DEFAULT_TAGS
    },
    {
        "first_name": "Max",
        "last_name": "Battaglia",
        "email": None,
        "phone_number": "2014191029",
        "birthday": None,
        "location": "North New Jersey",
        "university": "CMU",
        "interests": "Communication, Business",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Business Administration",
        "job_title": "Business Development",
        "current_company": "Eagle Corp",
        "profile_image_url": "https://randomuser.me/api/portraits/men/3.jpg",
        "linkedin_url": None,
        "recent_tags": DEFAULT_TAGS
    },
    {
        "first_name": "Stan",
        "last_name": "Osipenko",
        "email": "osipenko@cmu.edu",
        "phone_number": None,
        "birthday": "04/15/2005",
        "location": "London",
        "university": "CMU",
        "interests": "Self Improvement, Coding Competitions, Physicality",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Computer Science",
        "job_title": "Software Engineer",
        "current_company": "London Tech",
        "profile_image_url": "https://randomuser.me/api/portraits/men/4.jpg",
        "linkedin_url": "https://linkedin.com/in/stanosipenko",
        "recent_tags": DEFAULT_TAGS
    },
    {
        "first_name": "Corwin",
        "last_name": "Cheung",
        "email": "corwintcheung@gmail.com",
        "phone_number": "9173706098",
        "birthday": "04/15/2005",
        "location": "NYC, New York",
        "university": "Harvard",
        "interests": "Entrepreneurship, Self Development, Physicality, Reading",
        "high_school": "Riverdale",
        "gender": "Male",
        "ethnicity": "Asian",
        "uni_major": "Economics",
        "job_title": "Entrepreneur",
        "current_company": "Self-employed",
        "profile_image_url": "https://randomuser.me/api/portraits/men/5.jpg",
        "linkedin_url": "https://linkedin.com/in/corwincheung",
        "recent_tags": DEFAULT_TAGS
    },
    {
        "first_name": "Steve",
        "last_name": "Jobs",
        "email": "steve@apple.com",
        "phone_number": "4085551234",
        "birthday": "04/15/2005",
        "location": "Palo Alto, California",
        "university": "Reed College (dropped out)",
        "interests": "Technology, Design, Innovation",
        "high_school": "Homestead High School",
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": None,
        "job_title": "Co-founder and CEO",
        "current_company": "Apple Inc.",
        "profile_image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Steve_Jobs_Headshot_2010-CROP_%28cropped_2%29.jpg/800px-Steve_Jobs_Headshot_2010-CROP_%28cropped_2%29.jpg",
        "linkedin_url": None,
        "recent_tags": None
    },
    {
        "first_name": "Elon",
        "last_name": "Musk",
        "email": "elon@tesla.com",
        "phone_number": None,
        "birthday": "04/15/2005",
        "location": "Austin, Texas",
        "university": "University of Pennsylvania",
        "interests": "Space Exploration, Electric Vehicles, AI, Renewable Energy",
        "high_school": "Pretoria Boys High School",
        "gender": "Male",
        "ethnicity": None,
        "uni_major": "Physics and Economics",
        "job_title": "CEO",
        "current_company": "Tesla, SpaceX, X",
        "profile_image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Elon_Musk_Royal_Society_%28crop2%29.jpg/800px-Elon_Musk_Royal_Society_%28crop2%29.jpg",
        "linkedin_url": None,
        "recent_tags": None
    },
    {
        "first_name": "Sheryl",
        "last_name": "Sandberg",
        "email": "sheryl@meta.com",
        "phone_number": "6505551234",
        "birthday": "04/15/2005",
        "location": "Menlo Park, California",
        "university": "Harvard University",
        "interests": "Leadership, Women in Tech, Management",
        "high_school": None,
        "gender": "Female",
        "ethnicity": None,
        "uni_major": "Economics",
        "job_title": "Former COO",
        "current_company": "Meta Platforms",
        "profile_image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7c/Sheryl_Sandberg_2013.jpg/800px-Sheryl_Sandberg_2013.jpg",
        "linkedin_url": "https://linkedin.com/in/sherylsandberg",
        "recent_tags": None
    },
    {
        "first_name": "Mark",
        "last_name": "Zuckerberg",
        "email": None,
        "phone_number": None,
        "birthday": "04/15/2005",
        "location": "Palo Alto, California",
        "university": "Harvard University (dropped out)",
        "interests": "Social Media, Virtual Reality, Artificial Intelligence",
        "high_school": "Phillips Exeter Academy",
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Computer Science",
        "job_title": "Co-founder and CEO",
        "current_company": "Meta Platforms",
        "profile_image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/18/Mark_Zuckerberg_F8_2019_Keynote_%2832830578717%29_%28cropped%29.jpg/800px-Mark_Zuckerberg_F8_2019_Keynote_%2832830578717%29_%28cropped%29.jpg",
        "linkedin_url": None,
        "recent_tags": None
    },
    {
        "first_name": "Satya",
        "last_name": "Nadella",
        "email": "satya@microsoft.com",
        "phone_number": "4255551234",
        "birthday": "04/15/2005",
        "location": "Redmond, Washington",
        "university": "University of Wisconsin-Milwaukee",
        "interests": "Cloud Computing, Business Transformation, AI",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "Indian",
        "uni_major": "Computer Science",
        "job_title": "CEO",
        "current_company": "Microsoft",
        "profile_image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Satya_Nadella.jpg/800px-Satya_Nadella.jpg",
        "linkedin_url": "https://linkedin.com/in/satyanadella",
        "recent_tags": None
    }
]

def insert_sample_users():
    """Insert sample people into the database."""
    # SQL INSERT command template - adjusted to match our table schema
    insert_sql = """
    INSERT INTO people (
        first_name, last_name, email, phone_number, birthday,
        location, university, interests, high_school,
        gender, ethnicity, uni_major, job_title, current_company,
        profile_image_url, linkedin_url, recent_tags
    )
    VALUES (
        %(first_name)s, %(last_name)s, %(email)s, %(phone_number)s, %(birthday)s,
        %(location)s, %(university)s, %(interests)s, %(high_school)s,
        %(gender)s, %(ethnicity)s, %(uni_major)s, %(job_title)s, %(current_company)s,
        %(profile_image_url)s, %(linkedin_url)s, %(recent_tags)s
    );
    """

    try:
        # Connect to the Railway Postgres instance
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()

        # Insert each sample record
        for person in sample_data:
            cursor.execute(insert_sql, person)

        # Commit the transaction
        conn.commit()
        print("Sample user data inserted successfully.")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        return False

if __name__ == "__main__":
    insert_sample_users()
