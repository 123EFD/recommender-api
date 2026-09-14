import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Annotated
from typing import List, Dict
import os
import psycopg

router = APIRouter(prefix = "/bundler", tags=["Bundler"])

DB_PATH = "resources.db"

def get_db_connection():
    db_url = os.getenv("DATABASE_URL")
    if db_url is None:
        raise ValueError("DATABASE_URL environment variable is not set")
    return psycopg.connect(db_url)

class BundleRequest(BaseModel):
    minutes_available: Annotated[int, Field(gt=0, lt=241)]
    topic: str | None = None

class ResourceItem(BaseModel):
    resource_id: str
    topic: str
    duration_min: int
    type: str
    content: str

def _open() -> sqlite3.Connection:
    return sqlite3.connect(DB_PATH)

@router.post("/create", response_model=List[ResourceItem])

def create_bundle(req: BundleRequest):
    con = _open()
    sqlite_cur = con.cursor()
    
    topic = req.topic.strip() if req.topic else None
    candidates = []

    if topic:
        fuzzy_topic = f"%{topic}%"
        
        try: 
            with get_db_connection() as conn:
                with conn.cursor() as neon_cur:
                    neon_cur.execute(
                        """
                        SELECT title ,subject_tag ,url ,resource_type
                        FROM learning_resources
                        WHERE subject_tag ILIKE %s OR title ILIKE %s
                        LIMIT 3;
                        """,
                        (fuzzy_topic, fuzzy_topic)
                    )
                    results = neon_cur.fetchall()     
                        
            #loop through `results` and append to `candidates`
            for rows in results:
                candidates.append((rows[0], rows[1], 10, rows[3], rows[2]))
        except Exception as e:
            print(f"Error occurred while fetching resources: {e}")
            raise HTTPException(status_code=500, detail="Internal Server Error")
        
        # Exact match for short words (C, C#, R, Go) to prevent unrelated topic matching
        # 1. First try an exact match
    if topic:
        # 1. First try an exact match in SQLite
        sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content 
                FROM micro_resources WHERE topic COLLATE NOCASE = ? ORDER BY RANDOM();"""
        sqlite_cur.execute(sql, (topic,))
        sqlite_candidates = sqlite_cur.fetchall()
        
        # 2. If exact match fails, do a fuzzy match for the category
        if not sqlite_candidates:
            sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content 
                    FROM micro_resources WHERE topic LIKE '%' || ? || '%' COLLATE NOCASE ORDER BY RANDOM();"""
            # Use a slightly stripped word for better matching (e.g., 'Algorithm' instead of 'Algorithms')
            search_term = topic[:-1] if topic.endswith('s') else topic
            sqlite_cur.execute(sql, (search_term,))
            sqlite_candidates = sqlite_cur.fetchall()
            
        # 3. Final Fallback to General CS just in case
        if not sqlite_candidates:
            print(f"Topic '{topic}' not found. Falling back to General CS.")
            sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                    FROM micro_resources WHERE topic COLLATE NOCASE = 'General CS' ORDER BY RANDOM();"""
            sqlite_cur.execute(sql)
            sqlite_candidates = sqlite_cur.fetchall()
            
        # Add all SQLite flashcards without overwriting or skipping
        candidates.extend(sqlite_candidates)
            
    else:
        # If user left topic blank, grab everything
        sql = """SELECT CAST(id AS TEXT), topic, CAST(duration_min AS INT), type, content 
                FROM micro_resources ORDER BY RANDOM();"""
        sqlite_cur.execute(sql)
        candidates.extend(sqlite_cur.fetchall())

    # Prioritize longer resources (Videos, PYQs) over Flashcards
    candidates.sort(key=lambda x: x[2], reverse=True)

    # greedy first-fit knapsack 
    total = 0
    bundle = []
    for rid, topic_name, dur, rtype, content in candidates:
        if total + dur <= req.minutes_available:
            bundle.append(ResourceItem(resource_id=rid, topic=topic_name, duration_min=dur, type=rtype, content=content))
            total += dur
        if total >= req.minutes_available:
            break
        
    if total < req.minutes_available and topic != 'General CS':
        remaining_time = req.minutes_available - total
        print(f"Could not fill the requested {req.minutes_available} minutes with topic '{topic}'. Total allocated: {total} minutes. Remaining time: {remaining_time} minutes.")
        
        sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                FROM micro_resources WHERE topic COLLATE NOCASE = 'General CS' ORDER BY RANDOM();"""
        sqlite_cur.execute(sql)
        fallback_candidates = sqlite_cur.fetchall()
        
        for rid, topic_name, dur, rtype, content in fallback_candidates:
            #prevent duplicates 
            if any(r.resource_id == rid for r in bundle):
                continue
            if total + dur <= req.minutes_available:
                bundle.append(ResourceItem(resource_id=rid, topic=topic_name, duration_min=dur, type=rtype, content=content))
                total += dur
            if total >= req.minutes_available:
                break
            
    con.close()
    
    if not bundle:
        raise HTTPException(status_code=404, detail="No resources found.")
    
    return bundle