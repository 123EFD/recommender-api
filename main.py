import os

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, UploadFile, File
import fitz
from langchain_text_splitters import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer, CrossEncoder
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
import time

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
    cross_encoder = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-6-v2')
    print("PDF Engine Ready!")
except Exception as e:
    print(f"Embedding Engine Error: {e}")
    
class LearningResource(BaseModel):
    subject_tag: str
    course_code: str
    title: str
    url: str
    resource_type: str
    explanation: Optional[str] = None

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
                
                for res in db_resources:
                    # Generate an explanation using Gemini
                    explain_prompt = f"""
                    A university student is struggling with the course '{res.subject_tag}'. 
                    I am recommending a resource titled '{res.title}'. 
                    Write a single, encouraging sentence explaining why watching/reading this will help them improve their grade.
                    """
                    explain = client.models.generate_content(
                        model="gemini-2.5-flash",
                        contents=explain_prompt
                    )
                    res.explanation = explain.text.strip() if explain.text else ""
                    resource_links.append(res)
                
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
        
        #chunk text
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000, 
            chunk_overlap=200,
            separators=["\n\n", "\n", ".", " ", ""]
        )
        
        chunks_with_pages= []
                
        #READ PDF AND TRACK PAGES
        #enumerate allows i ndex number of the vector to be kept track with the text chunk
        for page_num, page in enumerate(doc.pages(), start=1):
            page_text = page.get_text()
            if not page_text.strip():
                continue
                
            page_chunks = text_splitter.split_text(page_text)
                    
            for chunk in page_chunks:
                annotated_chunk = f"[Page {page_num}]\n{chunk}"
                chunks_with_pages.append(annotated_chunk)
                        
        if not chunks_with_pages:
            raise HTTPException(status_code=400, detail="No valid text chunks extracted from PDF")
                
        # Embed the annotated chunks
        embeddings = embedder.encode(chunks_with_pages)
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                for i, chunk_text in enumerate(chunks_with_pages):
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
            "chunks_processed": len(chunks_with_pages)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process PDF: {str(e)}")
    
#RAG for Q&A AI Chatbox
@app.post("/chat")
def ask_pdf_question(request: ChatRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API Key is missing.")
    
    try:
        # 1. CONSTRUCT PROMPT 
        prompt = f"""
        You are a search query optimizer for a Semantic Vector Database. 
        CRITICAL RULE: NEVER use boolean operators like "OR", "AND", or parentheses "()".
        Write the query as a natural, plain-English sentence.
        Only output the query itself, nothing else.
        Student Question: {request.question}
        """
        
        #2. generate answer with QUERY TRANSFORMATION
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
        )
        
        
        #-->Later uncomment this: 
        # optimized_query = response.text.strip() if response.text else request.question
        
        optimized_query = request.question
        optimized_query = optimized_query.replace('"', '')
        
        print(f"Original: {request.question} | Optimized: {optimized_query}")
        
        #3. embedding-question convert into 384-d vector
        question_vector = str(embedder.encode(optimized_query).tolist())
        
        #4.hybrid retireval using pgvector(search similar meaning) and tsvector(search keywords)
        retrieved_text = ""
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT chunk_text 
                    FROM document_chunks
                    WHERE document_name = %s
                    ORDER BY 
                        -- Weight 1: Semantic Meaning (70%)
                        ((1.0 - (embedding <=> %s::vector)) * 0.7) 
                        + 
                        -- Weight 2: Exact Keyword Match (30%)
                        (ts_rank(to_tsvector('english', chunk_text), plainto_tsquery('english', %s)) * 0.3)
                    DESC
                    LIMIT 30 
                    """,
                    (request.filename, question_vector, optimized_query)
                )
                
                rows = cur.fetchall()
        
        #5. Re-Rank the results using the Cross-Encoder
        final_source_count = 0
        if rows:
            #Create pairs of [Question, Document_Chunk]
            sentence_pairs = [[optimized_query, row[0]] for row in rows]
            
            scores = cross_encoder.predict(sentence_pairs)
            
            # Sort the chunks by their re-ranking scores using tuple[key, value(text)]
            scored_results = list(zip(scores, [row[0] for row in rows]))
            scored_results.sort(key=lambda x: x[0], reverse=True)
            
            # Select the top 12 chunks
            top_results = scored_results[:12]
            final_source_count = len(top_results)
            
            #6. unpack the tuple into (score, chunk_text) and use chunk_text!
            for i, (score, chunk_text) in enumerate(top_results):
                retrieved_text += f"\n--- Excerpt {i+1} ---\n{chunk_text}\n"
                
        time.sleep(2)
        
        #7. Final Answer Generation with retrieved text as context
        final_prompt = f"""         
        Thinks as an educational AI assistant helping Malaysian student, especially those studying Computer Science related subjects.
        Your goal is to provide precise, comprehensive, and highly accurate answers to the student's question.
        
        RULES:
        1. Base your factual information STRICTLY on the Context Excerpts provided below.
        2. If the user asks for a recommendation, you ARE allowed to provide subjective, expert advice. Base your recommendation on general software engineering industry principles (e.g., practical application vs. theoretical value) using the course descriptions provided.
        3. Do not say "I do not possess personal opinions." You must confidently advise the student.
        4. Synthesize the information logically using bullet points.
        5. If a specific course code from the user's prompt is completely missing from the excerpts, explicitly state which ones are missing at the end.
        
        Context Excerpts:
        {retrieved_text}
        
        Student's Question: {request.question}
        
        Answer:
        """
        
        final_response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=final_prompt
        )
                    
        return {
            "question": request.question,
            "answer": final_response.text,
            "sources_used": final_source_count
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