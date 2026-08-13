import sqlite3
import re

conn = sqlite3.connect('resources.db')
cursor = conn.cursor()

# 1. Delete Math / Junk Flashcards
# We'll delete flashcards from 'General CS' that contain numbers but no actual letters,
# or are ridiculously short (e.g., pure math equations).
cursor.execute("SELECT id, content FROM micro_resources WHERE topic = 'General CS' AND type = 'flashcard'")
rows = cursor.fetchall()

junk_count = 0
for row_id, content in rows:
    # If the front or back doesn't contain at least one alphabetical word of length 3+, it's likely junk math
    clean_text = re.sub(r'[^a-zA-Z\s]', '', content)
    words = [w for w in clean_text.split() if len(w) >= 3]
    if len(words) < 2 or len(content) < 30:
        cursor.execute("DELETE FROM micro_resources WHERE id = ?", (row_id,))
        junk_count += 1
        
print(f"Deleted {junk_count} math/junk flashcards.")

# 2. Fix Merged Data Science Flashcards
cursor.execute("SELECT id, content FROM micro_resources WHERE topic = 'Data Science' AND type = 'flashcard'")
ds_rows = cursor.fetchall()

fixed_count = 0
for row_id, content in ds_rows:
    # If it contains multiple questions
    if content.count('**Question:**') > 1:
        # Delete the old merged row
        cursor.execute("DELETE FROM micro_resources WHERE id = ?", (row_id,))
        
        # Split it into individual flashcards
        # The AI formats it as "**Question:** What is... \n**Answer:** It is..."
        questions = re.findall(r'\*\*Question:\*\* (.*?)\n', content)
        answers = re.findall(r'\*\*Answer:\*\* (.*?)(?=\n\n|\n###|$)', content, re.DOTALL)
        
        for i in range(min(len(questions), len(answers))):
            new_content = f"**Question:**\n{questions[i].strip()}\n\n**Answer:**\n{answers[i].strip()}"
            cursor.execute("""
                INSERT INTO micro_resources (topic, type, content, duration_min, cognitive_load)
                VALUES (?, ?, ?, ?, ?)
            """, ("Data Science", "flashcard", new_content, 2, 2))
            fixed_count += 1

conn.commit()
print(f"Split {len(ds_rows)} merged rows into {fixed_count} individual flashcards.")
conn.close()
