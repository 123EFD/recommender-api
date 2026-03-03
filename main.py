import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, UploadFile, File
import fitz
from langchain_text_splitters import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import torch
import torch.nn as nn
import joblib
import numpy as np
from typing import List, Optional
import psycopg 
import requests
from google import genai
import httpx

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    client = genai.Client(api_key=GEMINI_API_KEY)

COURSE_MAPPING = {
    "WIX1001": "Computing Mathematics I",
    "WIA1002": "Fundamentals of Programming Java",
    "WIX1003": "Computer Systems and Organization",
    "WIA1003": "Computer System Architecture",
    "WIA1006": "Machine Learning",
    "WIA1005": "Network Technology Foundation",
    "WIA2004": "Operating Systems",
    "WIA2007": "Mobile Application Development",
    "WIA2003": "Probability and Statistics"
}

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

class ChatRequest(BaseModel):
    question: str
    filename: str
    
class URLRequest(BaseModel):
    url: str

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
    
print("Loading PDF Embedding Model...")
try:
    embedder  = SentenceTransformer('all-MiniLM-L6-v2')
    print("PDF Engine Ready!")
except Exception as e:
    print(f"Embedding Engine Error: {e}")
    
class LearningResource(BaseModel):
    subject_tag: str
    course_code: str
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
        #'with' close  the connection and cursor after block finished 
        with get_db_connection() as conn:
            # Open a cursor to perform database operations(INSERT, SELECT)
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT subject_tag, title, url, resource_type, course_code
                    FROM learning_resources 
                    WHERE course_code = ANY(%s)
                    """,
                    (subjects,)
                )
                
                rows = cur.fetchall()  
                
                #convert database rows to Pydantic objects
                for row in rows:
                    resources_list.append(LearningResource(
                        subject_tag=row[0], 
                        title=row[1], 
                        url=row[2], 
                        resource_type=row[3],
                        course_code=row[4]
                    ))
    except Exception as e:#log to Sentry later
        print(f"Database Error: {e}")
        
    return resources_list

def fetch_and_store_yt_videos(course_code: str) -> Optional[LearningResource]:
    """Fetches a video from YouTube if not in Neon, and saves it to the database."""
    if not YOUTUBE_API_KEY:
        print("YouTube API key not set. Skipping YouTube fetch.")
        return None
    
    # Translate code to name, default to the code itself if not found
    course_name = COURSE_MAPPING.get(course_code, course_code)
    
    search_query = f"{course_name} full course"
    
    url = "https://www.googleapis.com/youtube/v3/search"
    
    params = {
        "part": "snippet",
        "q": search_query,
        "type": "video",
        "maxResults": 1, #later can test 
        "key": YOUTUBE_API_KEY
    }
    
    try:
        response = requests.get(url, params=params)
        if response.status_code == 200:
            data = response.json()
            if data.get("items"):
                video = data["items"][0]
                #Build the resource object
                title = video["snippet"]["title"].replace("&quot;", "'").replace("&#39;", "'")
                video_id = video["id"]["videoId"]
                video_url = f"https://www.youtube.com/watch?v={video_id}"
                
                print(f"Auto-Discovered YouTube Video for {course_code}: {title}")
                
                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                            VALUES (%s, %s, %s, %s, %s) # "%s" prevent SQL injection 
                            """,
                            (course_code, course_name, title, video_url, "video")
                        )
                    conn.commit() # Save the new video resource to Neon for future queries
                return LearningResource(
                    subject_tag=course_name, 
                    course_code=course_code, 
                    title=title, 
                    url=video_url, 
                    resource_type="video")
    except Exception as e:
        print(f"YouTube API Error: {e}")
    
    return None
    
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
            
            for subject_code in recommended_subjects:
                db_resources = fetch_neon_resources([subject_code])
                
                if db_resources:
                    print(f"Found {len(db_resources)} resources in Neon for {subject_code}.")
                    resource_links.extend(db_resources)
                else:
                    print(f"No resources in Neon for {subject_code}. Triggering YouTube API...")
                    new_video = fetch_and_store_yt_videos(subject_code)
                    
                    if new_video:
                        resource_links.append(new_video)
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
    
@app.post("/upload-pdf")
async def process_and_store_pdf(file: UploadFile = File(...)):
    try:
        #Read pdf 
        file_bytes = await file.read()
        doc = fitz.open(stream=file_bytes, filetype="pdf")
        
        full_text = ""
        for page in doc:
            full_text += str(page.get_text())
            
        if not full_text.strip():
            raise HTTPException(status_code=400, detail="No text extracted from PDF")
        
        #chunk text
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, 
            chunk_overlap=200,
            separators=["\n\n", "\n", ".", " ", ""]
        )
        chunks = text_splitter.split_text(full_text)
        
        #embed  chunks 
        embeddings = embedder.encode(chunks)
        
        #store chunks in vector db
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                #enumerate allows index number of the vector to be kept track with the text chunk
                for i, chunk_text in enumerate(chunks):
                    
                    # Convert the numpy array to a standard Python list, then to a string
                    vector_string = str(embeddings[i].tolist())
                    
                    cur.execute(
                        """
                        INSERT INTO document_chunks (document_name, chunk_text, embedding) 
                        VALUES (%s, %s, %s)
                        """,
                        (file.filename, chunk_text, vector_string)
                    )
            conn.commit()
            
        return  {
            "message" : "Success",
            "filename": file.filename,
            "chunks_processed": len(chunks)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process PDF: {str(e)}")
    
#RAG for Q&A AI Chatbox
@app.post("/chat")
def ask_pdf_question(request: ChatRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API Key is missing.")
    
    try:
        #1. embedding-question convert into 384-d vector
        question_vector = str(embedder.encode(request.question).tolist())
        
        #2. retrieve relevant chunks from neon
        retrieved_text = ""
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT chunk_text 
                    FROM document_chunks
                    WHERE document_name = %s
                    ORDER BY embedding <=> %s::vector
                    LIMIT 8 -- Adjust the number of chunks to retrieve as needed
                    """,
                    (request.filename, question_vector)
                )
                
                rows = cur.fetchall()
                
                # Combine the top 3 chunks into a single text block
                for i, row in enumerate(rows):
                    retrieved_text += f"\n--- Excerpt {i+1} ---\n{row[0]}\n"
                    
        # 3. CONSTRUCT PROMPT         
        prompt = f"""
        Thinks as an educational AI assistant helping Malaysian student.
        Your goal is to provide precise, comprehensive, and highly accurate answers to the student's question.
        
        RULES:
        1. Base your answer STRICTLY on the Context Excerpts provided below.
        2. Synthesize the information logically. Use clear bullet points and bold text for readability.
        3. Maintain a professional, academic tone in English. Do not use slang.
        4. If the exact answer is not in the excerpts, do your best to infer from the provided context, but clearly state what is missing.

        Context Excerpts:
        {retrieved_text}
        
        Student's Question: {request.question}
        
        Answer:
        """
        
        #generate answer
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        
        return {
            "question": request.question,
            "answer": response.text,
            "sources_used": len(rows)
        }
        
    except Exception as e:
        print(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to generate answer: {str(e)}")
    
@app.post("/analyze-pdf-url")
async def process_pdf_from_url(request: dict):
    url = request.get("url")
    if not url:
        raise HTTPException(status_code=400, detail="URL is required.")
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(url)
            if response.status_code != 200:
                raise HTTPException(status_code=400, detail="Could not download PDF from URL")
            
            #open pdf from stream
            file_bytes = response.content
            doc = fitz.open(stream=file_bytes, filetype="pdf")

            full_text = ""
            for page in doc:
                full_text += str(page.get_text())
                
            if not full_text.strip():
                raise HTTPException(status_code=400, detail="No text extracted from PDF")
            
            #chunk text
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=500, 
                chunk_overlap=50,
                separators=["\n\n", "\n", ".", " ", ""]
            )
            chunks = text_splitter.split_text(full_text)
            
            #embed  chunks 
            embeddings = embedder.encode(chunks)
            
            #store chunks in vector db
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    #enumerate allows index number of the vector to be kept track with the text chunk
                    for i, chunk_text in enumerate(chunks):

                        # Convert the numpy array to a standard Python list, then to a string
                        vector_string = str(embeddings[i].tolist())
                        
                        cur.execute(
                            """
                            INSERT INTO document_chunks (document_name, chunk_text, embedding) 
                            VALUES (%s, %s, %s)
                            """,
                            (url, chunk_text, vector_string)
                        )
                conn.commit()
                
            return  {
                "message" : "Success",
                "chunks_processed": len(chunks)
            }
    except Exception as e:
        error_msg = str(e)
        print(f"Chat Error: {error_msg}")
        if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg:
            raise HTTPException(status_code=429, detail="Gemini API rate limit exceeded. Please wait 30 seconds and try again later.")
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/library")
def get_pdf_library():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT DISTINCT document_name FROM document_chunks")
                rows = cur.fetchall()
                
                return [row[0] for row in rows]  # Return a list of document names
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))