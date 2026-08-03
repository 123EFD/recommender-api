import os
import zipfile
import sqlite3
import tempfile
import csv
from dotenv import load_dotenv
from groq import Groq
import httpx
import time
from pathlib import Path

load_dotenv()

# Paths to your assets
ASSETS_DIR = Path(__file__).parent.parent / "assets"
DB_PATH = Path(__file__).parent.parent / "resources.db"
FLASHCARDS_DIR = ASSETS_DIR / "flashcards"
PYQ_CSV = ASSETS_DIR / "questions-data-new.csv"
import sys
# Add the project root to sys.path so we can import the app module
sys.path.append(str(Path(__file__).parent.parent))
from app.groq_client import groq_chat


def setup_db():
    """Initializes the SQLite Database for micro-resources."""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS micro_resources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            topic TEXT,
            type TEXT, 
            content TEXT,
            duration_min INTEGER,
            cognitive_load INTEGER
        )
    """)
    conn.commit()
    return conn

def process_anki_apkg(conn, apkg_path):
    """
    An .apkg file is a ZIP archive. This function unzips it, 
    locates the Anki SQLite database, and extracts the flashcards.
    """
    print(f"Processing Flashcard Deck: {apkg_path.name}...")
    cursor = conn.cursor()
    
    with tempfile.TemporaryDirectory() as tmp_dir:
        # 1. Unzip the .apkg file
        with zipfile.ZipFile(apkg_path, 'r') as zip_ref:
            zip_ref.extractall(tmp_dir)
            
        # 2. Find the SQLite DB (usually collection.anki2 or collection.anki21)
        db_file = os.path.join(tmp_dir, 'collection.anki2')
        if not os.path.exists(db_file):
            db_file = os.path.join(tmp_dir, 'collection.anki21')
            
        if not os.path.exists(db_file):
            print(f"  [!] No valid collection.anki2 DB found in {apkg_path.name}")
            return
            
        # 3. Connect to the Anki DB and extract notes
        anki_conn = sqlite3.connect(db_file)
        anki_cursor = anki_conn.cursor()
        
        try:
            # flds contains front and back separated by \x1f
            anki_cursor.execute("SELECT tags, flds FROM notes")
            rows = anki_cursor.fetchall()
            
            count = 0
            for tags, flds in rows:
                fields = flds.split('\x1f')
                if len(fields) >= 2:
                    front = fields[0].replace('\n', '<br>')
                    back = fields[1].replace('\n', '<br>')
                    content = f"**Front:** {front}\n**Back:** {back}"
                    
                    # Assuming topic is the tags or a generic CS topic
                    topic = tags.strip() if tags else "Computer Science"
                    
                    cursor.execute("""
                        INSERT INTO micro_resources (topic, type, content, duration_min, cognitive_load)
                        VALUES (?, ?, ?, ?, ?)
                    """, (topic, 'flashcard', content, 2, 2))
                    count += 1
                    
            print(f"  [+] Extracted {count} flashcards from {apkg_path.name}")
        except Exception as e:
            print(f"  [!] Error reading Anki DB: {e}")
        finally:
            anki_conn.close()
            
    conn.commit()

def generate_solution_with_groq(question_text):
    """Uses Groq API to solve PYQ offline and extract a quick tip."""
    system_prompt = "You are an expert Computer Science professor. Solve this past-year exam question concisely. Then, provide a 1-sentence 'Quick Tip'."
    user_message = f"Question: {question_text}"
    
    try:
        return groq_chat(system_prompt=system_prompt, user_message=user_message, model="llama3-8b-8192")
    except Exception as e:
        print(f"  [!] Groq API Error: {e}")
        return None

def process_pyq_csv(conn, csv_path, max_rows=10):
    """
    Reads the PYQ CSV. 
    WARNING: We limit to `max_rows` by default so you don't exhaust your Groq API limits.
    """
    print(f"Processing PYQs from {csv_path.name} (Limit: {max_rows} rows)...")
    cursor = conn.cursor()
    
    # Fetch already processed questions to allow resuming
    cursor.execute("SELECT content FROM micro_resources WHERE type='pyq_solution'")
    existing_content = [row[0] for row in cursor.fetchall()]
    
    count = 0
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if count >= max_rows:
                break
                
            topic = row.get('topic', 'General')
            question = row.get('question', '')
            
            # Check if this question was already processed (exists in any content string)
            already_processed = any(question in content for content in existing_content)
            if already_processed:
                print(f"  -> Skipping (Already processed): {question[:50]}...")
                continue

            
            print(f"  -> Generating solution for: {question[:50]}...")
            solution = generate_solution_with_groq(question)
            
            if solution:
                content = f"**Question:** {question}\n\n**Solution & Tip:**\n{solution}"
                cursor.execute("""
                    INSERT INTO micro_resources (topic, type, content, duration_min, cognitive_load)
                    VALUES (?, ?, ?, ?, ?)
                """, (topic, 'pyq_solution', content, 5, 4))
                count += 1
                time.sleep(1) # Prevent hitting rate limits
                
    conn.commit()
    print(f"  [+] Generated {count} PYQ solutions.")

if __name__ == "__main__":
    print("Starting Offline Asset Processing...")
    conn = setup_db()
    
    # 1. Process Flashcards (.apkg files)
    if FLASHCARDS_DIR.exists():
        for apkg_file in FLASHCARDS_DIR.glob("*.apkg"):
            process_anki_apkg(conn, apkg_file)
    else:
        print("  [!] Flashcards directory not found.")
        
    # 2. Process PYQ CSV
    if PYQ_CSV.exists():
        process_pyq_csv(conn, PYQ_CSV, max_rows=10) # Set limit higher when ready!
    else:
        print("  [!] PYQ CSV not found.")
        
    conn.close()
    print("Offline Processing Complete! Data saved to resources.db")
