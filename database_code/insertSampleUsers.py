import psycopg2
from config import DATABASE_URL

# Sample data as a list of dictionaries
sample_data = [
    {
        "username": "danieltantsyura",
        "first_name": "Daniel",
        "last_name": "Tantsyura",
        "email": "dan.tantsyura@gmail.com",
        "phone_number": "2033135627",
        "location": "Westchester, New York",
        "university": "CMU",
        "field_of_interest": "Business, Investing, Networking, Long Term Success",
        "high_school": "Riverdale",
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Computer Science",
        "job_title": "Product Manager",
        "current_company": "Nexus Inc.",
        "profile_image_url": "https://randomuser.me/api/portraits/men/1.jpg",
        "linkedin_url": "https://linkedin.com/in/danieltantsyura"
    },
    {
        "username": "sorendupont",
        "first_name": "Soren",
        "last_name": "Dupont",
        "email": None,
        "phone_number": "6467998920",
        "location": "Brooklyn, New York",
        "university": "CMU",
        "field_of_interest": "Libertarian Economics, Math Competitions and Research, Coding",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Mathematics",
        "job_title": "Researcher",
        "current_company": "Tech Innovations",
        "profile_image_url": "https://randomuser.me/api/portraits/men/2.jpg",
        "linkedin_url": "https://linkedin.com/in/sorendupont"
    },
    {
        "username": None,
        "first_name": "Max",
        "last_name": "Battaglia",
        "email": None,
        "phone_number": "2014191029",
        "location": "North New Jersey",
        "university": "CMU",
        "field_of_interest": "Communication, Business",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Business Administration",
        "job_title": "Business Development",
        "current_company": "Eagle Corp",
        "profile_image_url": "https://randomuser.me/api/portraits/men/3.jpg",
        "linkedin_url": None
    },
    {
        "username": "stanosipenko",
        "first_name": "Stan",
        "last_name": "Osipenko",
        "email": "osipenko@cmu.edu",
        "phone_number": None,
        "location": "London",
        "university": "CMU",
        "field_of_interest": "Self Improvement, Coding Competitions, Physicality",
        "high_school": None,
        "gender": "Male",
        "ethnicity": "White",
        "uni_major": "Computer Science",
        "job_title": "Software Engineer",
        "current_company": "London Tech",
        "profile_image_url": "https://randomuser.me/api/portraits/men/4.jpg",
        "linkedin_url": "https://linkedin.com/in/stanosipenko"
    },
    {
        "username": "corwincheung",
        "first_name": "Corwin",
        "last_name": "Cheung",
        "email": "corwintcheung@gmail.com",
        "phone_number": "9173706098",
        "location": "NYC, New York",
        "university": "Harvard",
        "field_of_interest": "Entrepreneurship, Self Development, Physicality, Reading",
        "high_school": "Riverdale",
        "gender": "Male",
        "ethnicity": "Asian",
        "uni_major": "Economics",
        "job_title": "Entrepreneur",
        "current_company": "Self-employed",
        "profile_image_url": "https://randomuser.me/api/portraits/men/5.jpg",
        "linkedin_url": "https://linkedin.com/in/corwincheung"
    }
]

def insert_sample_users():
    """Insert sample users into the database."""
    # SQL INSERT command template - adjusted to match our table schema
    insert_sql = """
    INSERT INTO users (
        username, first_name, last_name, email, phone_number,
        location, university, field_of_interest, high_school,
        gender, ethnicity, uni_major, job_title, current_company,
        profile_image_url, linkedin_url
    )
    VALUES (
        %(username)s, %(first_name)s, %(last_name)s, %(email)s, %(phone_number)s,
        %(location)s, %(university)s, %(field_of_interest)s, %(high_school)s,
        %(gender)s, %(ethnicity)s, %(uni_major)s, %(job_title)s, %(current_company)s,
        %(profile_image_url)s, %(linkedin_url)s
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
