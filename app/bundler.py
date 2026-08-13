import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Annotated
from typing import List, Dict

router = APIRouter(prefix = "/bundler", tags=["Bundler"])

DB_PATH = "resources.db"

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
    cur = con.cursor()
    
    topic = req.topic.strip() if req.topic else None
    
    if topic:
        # Exact match for short words (C, C#, R, Go) to prevent unrelated topic matching
        # 1. First try an exact match
        sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content 
                 FROM micro_resources WHERE topic COLLATE NOCASE = ? ORDER BY RANDOM();"""
        cur.execute(sql, (topic,))
        candidates = cur.fetchall()
        
        # 2. If exact match fails (e.g. for "Machine Learning" which has many subtopics like "Python Machine Learning"),
        # do a fuzzy match for the category
        if not candidates:
            sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content 
                     FROM micro_resources WHERE topic LIKE '%' || ? || '%' COLLATE NOCASE ORDER BY RANDOM();"""
            # Use a slightly stripped word for better matching (e.g., 'Algorithm' instead of 'Algorithms')
            search_term = topic[:-1] if topic.endswith('s') else topic
            cur.execute(sql, (search_term,))
            candidates = cur.fetchall()
            
        # 3. Final Fallback to General CS just in case
        if not candidates:
            print(f"Topic '{topic}' not found. Falling back to General CS.")
            sql = """SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration, type, content
                     FROM micro_resources WHERE topic COLLATE NOCASE = 'General CS' ORDER BY RANDOM();"""
            cur.execute(sql)
            candidates = cur.fetchall()
            
    else:
        # If user left topic blank, grab everything
        sql = """SELECT CAST(id AS TEXT), topic, CAST(duration_min AS INT), type, content 
                 FROM micro_resources ORDER BY RANDOM();"""
        cur.execute(sql)
        candidates = cur.fetchall()

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
        cur.execute(sql)
        fallback_candidates = cur.fetchall()
        
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