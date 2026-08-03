#one time script to process past year questions to generate solutions and save inot new database
import csv
import sqlite3
import os
import httpx

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY environment variable is not set")

def setup_db():
    conn = sqlite3.connect("resources.db")
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS micro_resources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT,
            type TEXT, -- 'flashcard', 'pyq_solution', 'video_chunk'
            content TEXT,
            duration_min INTEGER,
            cognitive_load INTEGER
        )
    """)
    conn.commit()
    conn.close()
    
def generate_solution(question):
    prompt = f"""
    You are an expert in Computer Science professor.
    Solve these past-year exam question step-by-step.
    Then , provide a 1 sentence 'Quick Tip' and a 1-sentence 'Common Pitfall'.add()
    
    Question: {question}
    """
    
    payload = {
        "model" : "llama3-8b-8192", 
        "messages" : [{"role": "user", "content": prompt}],
        "temperature" : 0.2
    }
    
    headers = {"Authorization": f"Bearer {GROQ_API_KEY}"}
    response = httpx.post("https://api.groq.com/openai/v1/chat/completions", json=payload, headers=headers)
    
    if response.status_code == 200:
        return response.json()["choices"][0]["message"]["content"]
    return None

def process_questions(conn, pyq_csv_path):
    curosr = conn.cursor()
    with open(pyq_csv_path, 'r', encoding='utf-8') as file:
        reader = csv.DictReader(file)
        for row in reader:
            question = row['question']
            topic = row['topic']
            
            solution = generate_solution(question)
            
            if solution:
                curosr.execute("""
                    INSERT INTO micro_resources (topic, type, content, duration_min, cognitive_load)
                    VALUES (?, ?, ?, ?, ?)
                """, (row['topic'], 'pyq_solution', solution, 5, 4)) #5 min to read, cognitive load 4/5
    conn.commit()
    
if __name__ == "__main__":
    conn = setup_db()
    print("Database setup complete.")