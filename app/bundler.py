import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Annotated
from typing import List, Dict
import os
from dotenv import load_dotenv
import psycopg

load_dotenv()

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
                        
            # Normalize Neon resource types
            for rows in results:
                raw_type = (rows[3] or "reading").strip().lower()
                if raw_type in ("video", "youtube"):
                    normalized_type = "video"
                elif raw_type in ("pdf", "book", "article"):
                    normalized_type = raw_type
                else:
                    normalized_type = "reading"
                candidates.append((rows[0], rows[1], 10, normalized_type, rows[2]))
        except Exception as e:
            print(f"Error occurred while fetching resources: {e}")
            raise HTTPException(status_code=500, detail="Internal Server Error")
        
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
            sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                    FROM micro_resources WHERE topic COLLATE NOCASE = 'General CS' ORDER BY RANDOM();"""
            sqlite_cur.execute(sql)
            sqlite_candidates = sqlite_cur.fetchall()
            
        candidates.extend(sqlite_candidates)
            
    else:
        # If user left topic blank, grab everything
        sql = """SELECT CAST(id AS TEXT), topic, CAST(duration_min AS INT), type, content 
                FROM micro_resources ORDER BY RANDOM();"""
        sqlite_cur.execute(sql)
        candidates.extend(sqlite_cur.fetchall())

    # Partition candidates into categories to ensure curriculum diversity
    videos = [c for c in candidates if c[3] in ('video', 'video_chunk', 'youtube')]
    readings = [c for c in candidates if c[3] in ('pdf', 'book', 'article', 'reading', 'doc')]
    pyqs = [c for c in candidates if c[3] in ('pyq_solution', 'problem', 'quiz')]
    flashcards = [c for c in candidates if c[3] in ('flashcard', 'flashcards')]
    others = [c for c in candidates if c not in videos and c not in readings and c not in pyqs and c not in flashcards]

    bundle = []
    total = 0

    # 1. Multi-modal diversity phase: try to include at least 1 item from each available category
    pools = [videos, readings, pyqs, flashcards, others]
    for pool in pools:
        for c in pool:
            rid, topic_name, dur, rtype, content = c
            if total + dur <= req.minutes_available and not any(r.resource_id == rid for r in bundle):
                bundle.append(ResourceItem(resource_id=rid, topic=topic_name, duration_min=dur, type=rtype, content=content))
                total += dur
                break

    # 2. Greedy fill phase: fill remaining minutes with available candidates
    remaining_candidates = [c for c in candidates if not any(r.resource_id == c[0] for r in bundle)]
    remaining_candidates.sort(key=lambda x: x[2], reverse=True)
    for rid, topic_name, dur, rtype, content in remaining_candidates:
        if total + dur <= req.minutes_available:
            bundle.append(ResourceItem(resource_id=rid, topic=topic_name, duration_min=dur, type=rtype, content=content))
            total += dur
        if total >= req.minutes_available:
            break
        
    # 3. Fallback fill using General CS if time remains
    if total < req.minutes_available and topic != 'General CS':
        sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                FROM micro_resources WHERE topic COLLATE NOCASE = 'General CS' ORDER BY RANDOM();"""
        sqlite_cur.execute(sql)
        fallback_candidates = sqlite_cur.fetchall()
        
        for rid, topic_name, dur, rtype, content in fallback_candidates:
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