import psycopg2

# Your Railway connection string
conn_str = "postgresql://postgres:FPrWvNwkoqBIigGDjuBeJmMaJXCrjlgv@switchback.proxy.rlwy.net:50887/railway"

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
        "high_school": "Riverdale"
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
        "high_school": None
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
        "high_school": None
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
        "high_school": None
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
        "high_school": "Riverdale"
    }
]

# SQL INSERT command template - adjusted to match our table schema
insert_sql = """
INSERT INTO users (
    username, first_name, last_name, email, phone_number,
    location, university, field_of_interest, high_school
)
VALUES (
    %(username)s, %(first_name)s, %(last_name)s, %(email)s, %(phone_number)s,
    %(location)s, %(university)s, %(field_of_interest)s, %(high_school)s
);
"""

try:
    # Connect to the Railway Postgres instance
    conn = psycopg2.connect(conn_str)
    cursor = conn.cursor()

    # Insert each sample record
    for person in sample_data:
        cursor.execute(insert_sql, person)

    # Commit the transaction
    conn.commit()
    print("Sample user data inserted successfully.")

    cursor.close()
    conn.close()
except Exception as e:
    print("An error occurred:", e)
