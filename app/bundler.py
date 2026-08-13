#apply greedy first-fit knapsack to find best-fit study resources within given duration
# and return JSON array (study pack)

import sqlite3
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, conint
from typing import List, Dict

router = APIRouter(prefix = "/bundler", tags=["Bundler"])

DB_PATH = "resources.db"

class BundleRequest(BaseModel):
    minutes_available: conint(gt=0, lt=241)
    topic: str | None = None # optional filter (e.g., "Binary Search Trees")
    
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
    """Return a micro-bundle that fits exactly into `minutes_available`."""
    con = _open()
    cur = con.cursor()
    
    #extend with cognitive_load weighting later
    sql = """
    SELECT CAST(id AS TEXT) AS resource_id, topic, CAST(duration_min AS INT) AS duration,
           type, content
    FROM micro_resources
    WHERE (? IS NULL OR topic LIKE '%' || ? || '%')
    ORDER BY RANDOM();
    """
    
    cur.execute(sql, (req.topic, req.topic))
    candidates = cur.fetchall()
    
    #greedy first-fit knapsack 
    total = 0
    bundle = []
    for rid, topic, dur, type, content in candidates:
        if total + dur <= req.minutes_available:
            bundle.append(ResourceItem(resource_id=rid, topic=topic, duration_min=dur, type=type, content=content))
            total += dur
        if total >= req.minutes_available:
            break
        
    con.close()
    
    if not bundle :
        raise HTTPException(status_code=404, detail="No resources found for the given topic and duration.")
    
    return bundle