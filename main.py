import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import torch
import torch.nn as nn
import joblib
import numpy as np
from typing import List
import psycopg 

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

# 1. Initialize the FastAPI Application
app = FastAPI(title="Educational Resource Predictor API")

# 2. CORS middleware to allow requests from any origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allows any web page to connect during testing
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CourseGrade(BaseModel):
    name: str
    grade: float

# 2. Define the Pydantic Data Validator
class StudentProfile(BaseModel):
    income: int;
    hometown: int;
    department: int;
    preparation: int;
    attendance: int;
    gaming: int;
    ssc: float;
    last: float;
    courses: List[CourseGrade]

# 3. Re-define the PyTorch Architecture
class ResourcePredictorMLP(nn.Module):
    def __init__(self, input_size=8):
        super(ResourcePredictorMLP, self).__init__()
        self.layer1 = nn.Linear(input_size, 32)
        self.dropout = nn.Dropout(0.2)
        self.layer2 = nn.Linear(32, 16)
        self.output = nn.Linear(16, 1)

    def forward(self, x):
        x = torch.relu(self.layer1(x))
        x = self.dropout(x)
        x = torch.relu(self.layer2(x))
        x = self.output(x)
        return x
    
class LearningResource(BaseModel):
    title: str
    url: str
    resource_type: str

# 4. Load the Model and Scaler into Memory
print("Loading model and scaler...")
try:
    model = ResourcePredictorMLP()
    model.load_state_dict(torch.load('resource_predictor.pth', map_location=torch.device('cpu')))
    model.eval() # Turn off dropout for predictions
    
    scaler = joblib.load('student_scaler.pkl')
    print("AI Engine Ready!")
except Exception as e:
    print(f"Startup Error: {e}")
    
def get_db_connection():
    if DATABASE_URL is None:
        raise ValueError("DATABASE_URL environment variable is not set")
    conn = psycopg.connect(DATABASE_URL)
    return conn

def fetch_neon_resources(subjects: List[str]) -> List[LearningResource]:
    if not subjects:
        return []
    
    resources_list = []
    
    try: 
        #'with' ensure theconnection closed properly, connect to Neon
        with get_db_connection() as conn:
            # Open a cursor to perform database operations
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT title, url , resource_type FROM learning_resources WHERE subject_tag = ANY(%s)",
                    (subjects,)
                )
                
                rows = cur.fetchall()  
                
                #convert database rows to Pydantic objects
                for row in rows:
                    resources_list.append(LearningResource(
                        title=row[0], 
                        url=row[1], 
                        resource_type=row[2]
                    ))
    except Exception as e:#log to Sentry later
        print(f"Database Error: {e}")
        
    return resources_list

# 5. Define the API Endpoint
@app.post("/predict")
def predict_student_needs(student: StudentProfile):
    try:
        # Convert the incoming JSON into a flat Numpy array
        input_data = np.array([[
            student.income, student.hometown, student.department,
            student.preparation, student.attendance, student.gaming,
            student.ssc, student.last
        ]])
        
        # Apply the exact same scaling used during training
        scaled_data = scaler.transform(input_data)
        input_tensor = torch.tensor(scaled_data, dtype=torch.float32)
        
        # Make the prediction
        with torch.no_grad():
            raw_pred = model(input_tensor)
            probability = torch.sigmoid(raw_pred).item()
        
        needs_help = probability > 0.5
        
        risk_percentage = round(probability * 100, 2)
        
        recommended_subjects = [c.name for c in student.courses if c.grade < 3.0]

        if len(recommended_subjects) > 0 and needs_help:
            alert_level = "critical"
            msg = "🚨 Critical Risk: Poor study habits and failing current courses."
        elif len(recommended_subjects) > 0 and not needs_help:
            alert_level = "subject_alert"
            msg = "⚠️ Targeted Risk: Good general habits, but struggling in specific classes."
        elif len(recommended_subjects) == 0 and needs_help:
            alert_level = "habit_alert"
            msg = "⚠️ Habit Risk: Current grades are okay, but AI detects risky study patterns."
        else:
            alert_level = "safe"
            msg = "✅ On Track: Strong habits and passing all current courses."
            
        resource_links = []
        if needs_help and len(recommended_subjects) > 0:
            print(f"Querying Neon for subjects: {recommended_subjects}...")
            resource_links = fetch_neon_resources(recommended_subjects)
            print(f"Found {len(resource_links)} resources in Neon.")
        
        return {
            "alert_level": alert_level,
            "needs_resources": needs_help,
            "confidence_score": risk_percentage,
            #"recommended_subjects": recommended_subjects,
            "message": msg,
            "subjects_to_focus": recommended_subjects,
            "resource_links": resource_links
        }
    
        
    except Exception as e:
        # If anything breaks, return a safe 500 error code
        raise HTTPException(status_code=500, detail=str(e))