import sqlite3
import os

db_path = "resources.db"
conn = sqlite3.connect(db_path)
cur = conn.cursor()
cur.execute("SELECT content FROM micro_resources WHERE topic = 'Data Science' AND type = 'flashcard' LIMIT 3")
rows = cur.fetchall()
for r in rows:
    print("----- FLASHCARD -----")
    print(r[0])
    print("---------------------\n")
conn.close()
