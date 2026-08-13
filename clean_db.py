import sqlite3
import os

db_path = os.path.join(os.path.dirname(__file__), '..', '..', '..', '..', 'OneDrive', 'Documents', 'Coding', 'recommender-api', 'resources.db')
if not os.path.exists(db_path):
    db_path = "resources.db" # fallback

conn = sqlite3.connect(db_path)
conn.execute("DELETE FROM micro_resources WHERE type = 'flashcard'")
conn.commit()
count = conn.execute("SELECT COUNT(*) FROM micro_resources").fetchone()[0]
print(f"Deleted. Remaining: {count}")
conn.close()
