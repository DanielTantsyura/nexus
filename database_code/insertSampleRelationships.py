import psycopg2
import datetime
import random
from config import DATABASE_URL

def insert_sample_relationships():
    """Insert sample relationships between users in the database."""
    try:
        # Connect to the database
        conn = psycopg2.connect(DATABASE_URL)
        cursor = conn.cursor()
        
        # First, query to get the user IDs by name
        get_user_id_sql = "SELECT id, first_name, last_name FROM users;"
        cursor.execute(get_user_id_sql)
        
        user_ids = {}
        user_full_names = {}
        for id, first_name, last_name in cursor.fetchall():
            user_ids[first_name.lower()] = id
            user_full_names[f"{first_name.lower()} {last_name.lower()}"] = id
        
        print(f"Found {len(user_ids)} users in the database")
        
        # Define the relationships to add - no longer need to define both directions
        # since the add_connection function now handles bidirectional connections
        relationships = []
        
        # Add Daniel's connections to everyone
        daniel_id = user_ids.get('daniel')
        if daniel_id:
            # Connection to Soren
            soren_id = user_ids.get('soren')
            if soren_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': soren_id,
                    'description': "College friends",
                    'custom_note': "Met at CMU during freshman orientation. Works on math research projects. Good contact for academic collaborations.",
                    'tags': "college,math,research,academic",
                    'last_viewed': datetime.datetime.now()
                })
            
            # Connection to Max
            max_id = user_ids.get('max')
            if max_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': max_id,
                    'description': "College roommate",
                    'custom_note': "Shared apartment during sophomore year. Has good business connections in New Jersey.",
                    'tags': "college,roommate,business,new jersey",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=2)
                })
            
            # Connection to Stan
            stan_id = user_ids.get('stan')
            if stan_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': stan_id,
                    'description': "CS study group",
                    'custom_note': "Great programmer with expertise in algorithms. Now works in London, good international contact.",
                    'tags': "CS,algorithms,international,london",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=5)
                })
            
            # Connection to Corwin
            corwin_id = user_ids.get('corwin')
            if corwin_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': corwin_id,
                    'description': "High school friend",
                    'custom_note': "Entrepreneur with multiple startups. Good contact for investment opportunities.",
                    'tags': "high school,entrepreneur,investing,startups",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=1)
                })
                
            # Connection to Elon Musk
            elon_id = user_ids.get('elon')
            if elon_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': elon_id,
                    'description': "Met at tech conference",
                    'custom_note': "Briefly chatted at the AI Summit 2023. Expressed interest in my startup idea.",
                    'tags': "tech,AI,entrepreneurship,VIP",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=15)
                })
                
            # Connection to Steve Jobs
            steve_id = user_full_names.get('steve jobs')
            if steve_id:
                relationships.append({
                    'user_id': daniel_id,
                    'contact_id': steve_id,
                    'description': "Mentor",
                    'custom_note': "Read his biography and attended a talk he gave at Stanford. Major inspiration for my work.",
                    'tags': "inspiration,design,leadership,tech",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=60)
                })
        else:
            print("Warning: Daniel not found in the database")
        
        # Add Max's connections
        max_id = user_ids.get('max')
        if max_id:
            # Connection to Soren
            soren_id = user_ids.get('soren')
            if soren_id:
                relationships.append({
                    'user_id': max_id,
                    'contact_id': soren_id,
                    'description': "College friends",
                    'custom_note': "Met through Daniel at a campus event. Good at explaining complex economics concepts.",
                    'tags': "college,economics,academic",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=7)
                })
                
            # Connection to Sheryl Sandberg
            sheryl_id = user_ids.get('sheryl')
            if sheryl_id:
                relationships.append({
                    'user_id': max_id,
                    'contact_id': sheryl_id,
                    'description': "Professional contact",
                    'custom_note': "Met at a leadership conference in 2022. Discussed potential business collaborations.",
                    'tags': "business,leadership,networking,tech",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=20)
                })
        
        # Add Corwin's connections
        corwin_id = user_ids.get('corwin')
        if corwin_id:
            # Connection to Mark Zuckerberg
            mark_id = user_ids.get('mark')
            if mark_id:
                relationships.append({
                    'user_id': corwin_id,
                    'contact_id': mark_id,
                    'description': "Tech investor connection",
                    'custom_note': "Met at Harvard alumni event. Discussed potential investment in my startup.",
                    'tags': "investor,tech,harvard,networking",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=12)
                })
                
            # Connection to Satya Nadella
            satya_id = user_ids.get('satya')
            if satya_id:
                relationships.append({
                    'user_id': corwin_id,
                    'contact_id': satya_id,
                    'description': "Professional mentor",
                    'custom_note': "Attended his talk on cloud computing. Had a brief conversation afterwards about my business ideas.",
                    'tags': "mentor,cloud,business,technology",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=45)
                })
        
        # Add Steve Jobs connections
        steve_id = user_full_names.get('steve jobs')
        if steve_id:
            # Connection to Elon Musk
            elon_id = user_ids.get('elon')
            if elon_id:
                relationships.append({
                    'user_id': steve_id,
                    'contact_id': elon_id,
                    'description': "Fellow innovator",
                    'custom_note': "Met at several tech conferences. Admire his work in electric vehicles and space exploration.",
                    'tags': "innovation,tech,entrepreneurship,visionary",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=180)
                })
                
            # Connection to Mark Zuckerberg
            mark_id = user_ids.get('mark')
            if mark_id:
                relationships.append({
                    'user_id': steve_id,
                    'contact_id': mark_id,
                    'description': "Silicon Valley connection",
                    'custom_note': "Provided early mentorship on product design and company vision.",
                    'tags': "mentor,design,tech,leadership",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=365)
                })
        
        # Add tech titans connections
        elon_id = user_ids.get('elon')
        if elon_id:
            # Connection to Satya Nadella
            satya_id = user_ids.get('satya')
            if satya_id:
                relationships.append({
                    'user_id': elon_id,
                    'contact_id': satya_id,
                    'description': "Industry peer",
                    'custom_note': "Collaborated on AI safety initiatives. Potential partnership between Tesla and Microsoft on cloud computing.",
                    'tags': "AI,tech,business,cloud",
                    'last_viewed': datetime.datetime.now() - datetime.timedelta(days=30)
                })
        
        # Add Sheryl to Mark connection
        sheryl_id = user_ids.get('sheryl')
        mark_id = user_ids.get('mark')
        if sheryl_id and mark_id:
            relationships.append({
                'user_id': sheryl_id,
                'contact_id': mark_id,
                'description': "Colleague and friend",
                'custom_note': "Worked together at Meta for many years. Close professional relationship and friendship.",
                'tags': "work,leadership,meta,business",
                'last_viewed': datetime.datetime.now() - datetime.timedelta(days=5)
            })
        
        # Insert the relationships
        relationship_sql = """
        INSERT INTO relationships (
            user_id, contact_id, relationship_description, 
            custom_note, tags, last_viewed
        )
        VALUES (
            %(user_id)s, %(contact_id)s, %(description)s,
            %(custom_note)s, %(tags)s, %(last_viewed)s
        );
        """
        
        # First clear any existing relationships
        cursor.execute("DELETE FROM relationships;")
        print("Cleared existing relationships")
        
        for rel in relationships:
            # Insert in one direction
            cursor.execute(relationship_sql, rel)
            
            # Create the reverse direction data
            reverse_rel = {
                'user_id': rel['contact_id'],
                'contact_id': rel['user_id'],
                'description': rel['description'],
                'custom_note': rel['custom_note'],
                'tags': rel['tags'],
                'last_viewed': rel['last_viewed'] - datetime.timedelta(days=random.randint(1, 3))
            }
            cursor.execute(relationship_sql, reverse_rel)
        
        conn.commit()
        print(f"{len(relationships) * 2} relationships added successfully (bidirectional).")

        cursor.close()
        conn.close()
        return True
    except Exception as e:
        print("An error occurred:", e)
        return False

if __name__ == "__main__":
    insert_sample_relationships() 