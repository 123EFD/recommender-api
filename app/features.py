#router file for web app 

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import sqlite3

router = APIRouter()

class BundleRequest(BaseModel):
    minutes_available: int
    topic: str

def get_db_connection():
    # Connects to the database generated in Step 1
    conn = sqlite3.connect("resources.db")
    conn.row_factory = sqlite3.Row
    return conn

@router.post("/api/bundler")
def generate_study_bundle(req: BundleRequest):
    """
    Feature 3: Time-Budgeted Micro-Resource Bundler
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Fetch resources matching the topic
    cursor.execute("""
        SELECT * FROM micro_resources 
        WHERE topic = ? 
        ORDER BY RANDOM()
    """, (req.topic,))
    
    available_resources = cursor.fetchall()
    conn.close()
    
    bundle = []
    time_used = 0
    
    # Greedy Knapsack approach: Keep adding resources until time runs out
    for res in available_resources:
        if time_used + res['duration_min'] <= req.minutes_available:
            bundle.append(dict(res))
            time_used += res['duration_min']
            
        if time_used >= req.minutes_available:
            break
            
    if not bundle:
        raise HTTPException(status_code=404, detail="Not enough resources for this time budget.")
        
    return {
        "time_budget": req.minutes_available,
        "time_used": time_used,
        "bundle": bundle
    }