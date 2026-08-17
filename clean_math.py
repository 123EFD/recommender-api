import sqlite3
import re

def clean_math():
    conn = sqlite3.connect('resources.db')
    cur = conn.cursor()
    
    cur.execute("SELECT id, content FROM micro_resources WHERE type='flashcard'")
    rows = cur.fetchall()
    
    deleted = 0
    for row_id, content in rows:
        try:
            # Extract the front text
            if '**Answer:**' in content:
                front = content.split('**Answer:**')[0].replace('**Question:**', '').strip()
            elif '**Back:**' in content:
                front = content.split('**Back:**')[0].replace('**Front:**', '').strip()
            else:
                front = content
                
            # If front text contains absolutely no alphabet letters, it's pure math/junk
            if not re.search('[a-zA-Z]', front):
                cur.execute("DELETE FROM micro_resources WHERE id=?", (row_id,))
                deleted += 1
                print(f"Deleted math card: {front}")
        except Exception as e:
            print(f"Error parsing row {row_id}: {e}")
            
    conn.commit()
    conn.close()
    print(f"Total pure math flashcards deleted: {deleted}")

if __name__ == '__main__':
    clean_math()
