import os

from time import time

gs_bin_path = r'C:\Program Files\gs\gs10.06.0\bin'
if gs_bin_path not in os.environ.get('PATH', ''):
    os.environ['PATH'] += os.pathsep + gs_bin_path

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
import httpx
from groq import Groq
import nest_asyncio
#from llama_parse import LlamaParse <--will be used later, alter for Camelot
from ddgs import DDGS
import concurrent.futures
import camelot.io as camelot
import pandas as pd
import warnings
from fastapi.responses import FileResponse, StreamingResponse

os.makedirs("uploads", exist_ok=True)

#run async loops inside FastAPI smoothly
nest_asyncio.apply()


load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")
YOUTUBE_API_KEY = os.getenv("YOUTUBE_API_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)

COURSE_MAPPING = {
    "WIX1001": "Computing Mathematics I",
    "WIA1002": "Fundamentals of Programming Java",
    "WIX1003": "Computer Systems and Organization",
    "WIA1003": "Computer System Architecture",
    "WIA1006": "Machine Learning",
    "WIA1005": "Network Technology Foundation",
    "WIA2004": "Operating Systems",
    "WIA2007": "Mobile Application Development",
    "WIA2003": "Probability and Statistics",
    "WIA2006": "System Analysis and Design",
    "WIF2003": "Web Programming",
    "WIF2002": "Software Requirements Engineering",
    "WIF3001": "Software Testing",
    "WIF3002": "Software Process and Quality",
    "WIF3004": "Software Architecture and Design Paradigm",
    "WIF3005": "Software Maintenance and Evolution",
    "WIF3006": "Component Based Software Engineering ",
    "WIF3008": "Real Time Systems",
    "WIF3009": "Python for Scientific Computing",
    "WIF3010": "Programming Language Paradigm",
    "WIF3011": "Concurrent and Parallel Programming",
    "WIG3005": "Game Development",
    "WIC2008": "Internet of Things",
    "WIA2002": "Software Modeling"
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
class MessageRequest(BaseModel):
    filename: str
    role: str
    text: str
    
class RenameRequest(BaseModel):
    old_filename: str
    new_filename: str
    
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

#chat history table
def init_chat_db():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS chat_messages (
                        id SERIAL PRIMARY KEY,
                        filename TEXT NOT NULL,
                        role TEXT NOT NULL,
                        message_text TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )        
                """)
            conn.commit()
            print("Chat history table initialized successfully.")
    except Exception as e:
        print(f"Error initializing chat history table: {e}")
        
init_chat_db()

#task queue for processing large size pdf 
def init_jobs_db():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as curr:
                curr.execute("""
                    CREATE TABLE IF NOT EXISTS pdf_jobs (
                        filename TEXT PRIMARY KEY,
                        status TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )    
                """)
                
            conn.commit()
            print("PDF jobs table initialized successfully.")
    except Exception as e:
        print(f"Error initializing pdf jobs table: {e}")
        
init_jobs_db()

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
    
    response = None
    try:
        response = requests.get(url, params=params)
        
        if response.status_code != 200:
            print(f"❌ YouTube API Rejected the Request! Status Code: {response.status_code}")
            print(f"❌ YouTube Error Details: {response.text}")
            return None
        
        data = response.json()
        if not data.get("items"):
            print(f"⚠️ No YouTube videos found for query: {search_query}")
            return None
            
        video = data["items"][0]
        #Build the resource object
        title = video["snippet"]["title"].replace("&quot;", "'").replace("&#39;", "'")
        video_id = video["id"]["videoId"]
        video_url = f"https://www.youtube.com/watch?v={video_id}"
                
        print(f"Auto-Discovered YouTube Video for {course_code}: {title}")
        
        try:  
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                        VALUES (%s, %s, %s, %s, %s) 
                        """,
                        (course_code, course_name, title, video_url, "video")
                    )
                conn.commit() # Save the new video resource to Neon for future queries
            print(f"Saved YouTube video to Neon DB for course {course_code}.")
        except Exception as db_err:
            print(f"❌ Database Insertion Error: {db_err}")
            
        return LearningResource(
            subject_tag=course_name, 
            course_code=course_code, 
            title=title, 
            url=video_url, 
            resource_type="video"
        )
        
    except Exception as e:
        if response is not None:
            print(f"YouTube API Failed! Status Code: {response.status_code}")
            print(f"YouTube API Response: {response.text}")
        else:
            print(f"YouTube API Error: {e}")
    
    return None

def fetch_and_store_web_resources(course_code: str) -> List[LearningResource]:
    """Fetches an article and an PDF textbook using DuckDuckGo, and saves them to Neon."""
    course_name = COURSE_MAPPING.get(course_code, course_code)
    discovered_resources = []
    
    try:
        with DDGS() as ddgs:
            article_query = f"{course_name} (tutorial OR basics OR guide) computer science"
            article_results = list(ddgs.text(article_query, max_results=1))
            
            if article_results:
                item = article_results[0]
                title = str(item.get("title", f"{course_name} Guide"))
                url = str(item.get("href", ""))
                
                with get_db_connection() as conn:
                    with conn.cursor() as cur:
                        cur.execute(
                            """
                            INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                            VALUES (%s, %s, %s, %s, %s) 
                            """,
                            (course_code, course_name, title, url, "article")
                        )
                    conn.commit()
                
                discovered_resources.append(LearningResource(
                    subject_tag=course_name, course_code=course_code,
                    title=title, url=url, resource_type="article"
                ))
                print(f"✅ Auto-Discovered Article for {course_code}: {title}")
            
        pdf_query = f"{course_name} (textbook OR lecture notes OR pdf OR notes) filetype:pdf"
        pdf_results = list(ddgs.text(pdf_query, max_results=1))
        
        if pdf_results:
            item = pdf_results[0]
            title = str(item.get("title", f"{course_name} Textbook"))
            url = str(item.get("href", ""))
            
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO learning_resources (course_code, subject_tag, title, url, resource_type) 
                        VALUES (%s, %s, %s, %s, %s)
                        """,
                        (course_code, course_name, title, url, "book")
                    )
                conn.commit()
            
            discovered_resources.append(LearningResource(
                subject_tag=course_name, course_code=course_code,
                title=title, url=url, resource_type="book"
            ))
            print(f"✅ Auto-Discovered PDF for {course_code}: {title}")
            
    except Exception as e:
        print(f"Web Resource Discovery Error for {course_code}: {e}")
        
    return discovered_resources

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
            
        #fix AI overconfidence in risk score for good habits
        safe_ai_prob = max(0.10, probability)
            
        #heuristic habit score to improve model without retrain
        habit_risk = 0.15 #just a baseline of risk score, you can adjust 
        if student.attendance < 3: habit_risk += 0.25
        if student.preparation == 1 : habit_risk += 0.35
        elif student.preparation == 2 : habit_risk += 0.25
        if student.gaming == 1 : habit_risk += 0.30
        
        habit_risk = min(0.95, habit_risk) #prevent extreme values
        
        #ensemble rish score, model + heuristic
        final_probability = (probability * 0.6) + (habit_risk * 0.4)
        
        needs_help = final_probability > 0.5
        
        risk_percentage = round(final_probability * 100, 2)
        
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
        if len(recommended_subjects) > 0:
            print(f"Querying Neon for subjects: {recommended_subjects}...")
            
            for subject_code in recommended_subjects:
                db_resources = fetch_neon_resources([subject_code])
                
                if not db_resources:
                    
                    #Improvment async speed up fetching speed
                    with concurrent.futures.ThreadPoolExecutor() as executor:
                        future_yt = executor.submit(fetch_and_store_yt_videos, subject_code)
                        future_web = executor.submit(fetch_and_store_web_resources, subject_code)
                        
                        new_video = future_yt.result()
                        new_web_docs = future_web.result()
                    
                    if new_video:
                        db_resources.append(new_video)
                        
                    if new_web_docs:
                        db_resources.extend(new_web_docs)
                        
                def generate_explanation(res):
                    explain_prompt=f"""
                    A university student is struggling with the course '{res.subject_tag}'. 
                    I am recommending a {res.resource_type} titled '{res.title}'. 
                    Write a single, encouraging sentence explaining why watching/reading this will help them improve their grade.
                    """
                    try:
                        explain = client.chat.completions.create(
                            model="llama-3.1-8b-instant",
                            messages=[{"role": "user", "content": explain_prompt}],
                            max_tokens=80
                        )
                        content = explain.choices[0].message.content
                        res.explanation = content.strip() if content else ""
                    except Exception as e:
                        print(f"Groq Explanation Error: {e}")
                        res.explanation = "This resource covers foundational concepts to help you succeed."
                    return res
                
                with concurrent.futures.ThreadPoolExecutor() as executor:
                    resource_links.extend(list(executor.map(generate_explanation, db_resources)))
                    
        elif needs_help and len(recommended_subjects) == 0:
            habit_prompt = f"""
            A university student has good grades (GPA: {student.last}), but poor study habits. 
            They study {student.preparation} (1=Low, 3=High), attend {student.attendance} (1=Low, 4=High), 
            and game {student.gaming} (1=High, 0=Low).
            Write a highly personalized, 2-sentence warning about how these specific habits might cause 
            them to burn out or fail future, harder classes. Be direct.
            """
            
            try: 
                habit_response = client.chat.completions.create(
                    model="llama-3.1-8b-instant",
                    messages=[{"role": "user", "content": habit_prompt}],
                    max_tokens=100
                )
                
                resource_links.append({
                    "subject_tag": "General Advice",
                    "course_code": "Study Strategy",
                    "title": "AI Habit Analysis",
                    "url": "https://www.computersciencedegreehub.com/top-30-computer-science-programming-blogs-2014/", # Link to a good study habits blog
                    "resource_type": "article",
                    "explanation": habit_response.choices[0].message.content.strip() # type: ignore
                })
            except Exception as e:
                print(f"Habit LLM error: {e}")
                    
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
    file_path = f"uploads/{file.filename}"
        
    try:
        with open(file_path, "wb") as f:
            f.write(await file.read())
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save temp file: {str(e)}")
    
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO pdf_jobs (filename, status) 
                    VALUES (%s, %s) 
                    ON CONFLICT (filename)
                    DO UPDATE SET status = 'pending',created_at = CURRENT_TIMESTAMP
                    """,
                    (file.filename, 'pending')
                )
            conn.commit()        
            
        return {
            "message" : "Upload received. Processing in background.",
            "filename": file.filename,
            "status": "pending"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to queue PDF for processing: {str(e)}")
    
#RAG for Q&A AI Chatbox
@app.post("/chat")
def ask_pdf_question(request: ChatRequest):
    if not GROQ_API_KEY:
        raise HTTPException(status_code=500, detail="GROQ API Key is missing.")
    
    try:
        # 1. CONSTRUCT PROMPT 
        prompt = f"""
        You are a search query optimizer for a Semantic Vector Database. 
        Extract the core academic subjects and keywords from the student's question. 
        CRITICAL RULES: 
        1. NEVER use boolean operators like "OR", "AND", or parentheses "()".
        2. NEVER write SQL code (like SELECT or WHERE).
        3. Write the query as a simple, natural plain-English sentence.
        Only output the query itself, nothing else.
        Student Question: {request.question}
        """
        
        #2. generate answer with QUERY TRANSFORMATION
        #    response = client.models.generate_content(
        #        model="gemini-2.5-flash",
        #        contents=prompt
        #   )
        
        # Groq Call for Optimizer
        optimizer_response = client.chat.completions.create(
            model="llama-3.1-8b-instant", # We use the smaller 8B model here because it's wildly fast for simple tasks
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150
        )
        
        #-->Later uncomment this: 
        # optimized_query = response.text.strip() if response.text else request.question
        
        #optimized_query = request.question
        
        content = optimizer_response.choices[0].message.content if optimizer_response.choices else None
        optimized_query = content.strip() if content else request.question
        optimized_query = optimized_query.replace('"', '')
        
        print(f"Original: {request.question} | Optimized: {optimized_query}")
        
        #3. embedding-question convert into 384-d vector
        question_vector = str(embedder.encode(optimized_query).tolist())
        
        #4.hybrid retireval using pgvector(search similar meaning) and tsvector(search keywords)
        retrieved_text = ""
        chat_history_payload = [] # conversatoinal memory fetch last n messages
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT role, message_text 
                    FROM chat_messages 
                    WHERE filename = %s 
                    ORDER BY id DESC 
                    LIMIT 4
                    """,
                    (request.filename,)
                )
                past_messages = cur.fetchall()
                
                #reverse from oldest to newest 
                for row in reversed(past_messages):
                    db_role = row[0] 
                    llm_role = "assistant" if db_role == "ai" else "user" 
                    chat_history_payload.append({"role": llm_role, "content": row[1]})
                
                cur.execute(
                    """
                    SELECT chunk_text 
                    FROM document_chunks
                    WHERE document_name = %s
                    ORDER BY 
                        -- Weight 1: Semantic Meaning 
                        ((1.0 - (embedding <=> %s::vector)) * 0.7) 
                        + 
                        -- Weight 2: Exact Keyword Match 
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
                
        #time.sleep(2)
        
        #7. Final Answer Generation with retrieved text as context
        final_prompt = f"""         
        Thinks as an educational AI assistant helping Malaysian student, especially those studying Computer Science related subjects.
        Your goal is to provide precise, comprehensive, and highly accurate answers to the student's question.
        
        CRITICAL CONTEXT:
        The student is currently asking questions about the document named: '{request.filename}'.
        Whenever they ask "this book" or "this document", they are referring to '{request.filename}'.
        
        RULES:
        1. Base your factual information STRICTLY on the Context Excerpts provided below.
        2. If the user asks for a recommendation, you ARE allowed to provide subjective, expert advice. 
            Base your recommendation on general Information Technology or any related industry principles (e.g., practical application vs. theoretical value).
            Give examples as well which related to current Malaysia well-known companies or startups to make it more relevant to the student's future career.
        3. Do not say "I do not possess personal opinions." You must confidently advise the student.
        4. Synthesize the information logically using bullet points.
        5. State explicitly if specific answers cannot be found in the context excerpts.
        
        Context Excerpts:
        {retrieved_text}
        
        Student's Question: {request.question}
        
        Answer:
        """
        
        #Gemini
        #final_response = client.models.generate_content(
        #    model="gemini-2.5-flash",
        #    contents=final_prompt
        #)
        
        messages_payload = chat_history_payload + [{"role": "user", "content": final_prompt}]
        
        #streaming response
        def generate_stream():
            stream = client.chat.completions.create(
                model="llama-3.3-70b-versatile",
                messages=messages_payload,
                max_tokens=2048,
                stream=True
            )
            
            full_answer = ""
            
            for chunk in stream:
                if chunk.choices[0].delta.content is not None:
                    text_chunk = chunk.choices[0].delta.content
                    full_answer += text_chunk
                    yield text_chunk

            try:
                with get_db_connection() as conn:
                    with conn.cursor() as db_cur:
                        db_cur.execute(
                            "INSERT INTO chat_messages (filename, role, message_text) VALUES (%s, %s, %s)",
                            (request.filename, "ai", full_answer)
                        )
                    conn.commit()
            except Exception as db_err:
                print(f"Database Error: {db_err}")
                
        return StreamingResponse(generate_stream(), media_type="text/plain")
    
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
            raise HTTPException(status_code=429, detail="Groq API rate limit exceeded. Please wait 30 seconds and try again later.")
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/get-pdf/{filename}")
def get_pdf(filename: str):
    file_path = f"uploads/{filename}"
    if os.path.exists(file_path):
        return FileResponse(file_path, media_type="application/pdf")
    raise HTTPException(status_code=404, detail="File not found.")

@app.post("/save-message")
def save_message(req: MessageRequest):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO chat_messages (filename, role, message_text) 
                    VALUES (%s, %s, %s)
                    """,
                    (req.filename, req.role, req.text)
                )
            conn.commit()
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/get-chat/{filename}")
def get_chat(filename: str):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT role, message_text FROM chat_messages WHERE filename = %s ORDER BY id ASC",
                    (filename,)
                )
                rows = cur.fetchall()
                # Format into a list of dictionaries for Flutter
                return [{"role": row[0], "text": row[1]} for row in rows]
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) 
    
#status checker pdf processing so that futter won't timeout
@app.get("/job-status/{filename}")
def get_job_status(filename:str):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT status FROM pdf_jobs WHERE filename = %s", (filename,))
                row = cur.fetchone()
                if row: 
                    return {"filename": filename, "status" : row[0]}
                return {"status": "not found"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.get("/library")
def get_pdf_library():
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT filename FROM pdf_jobs ORDER BY created_at DESC")
                rows = cur.fetchall()
                return[row[0] for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.put("/rename-pdf")
def rename_pdf(req: RenameRequest):
    
    try:
        new_name = req.new_filename if req.new_filename.endswith('.pdf') else req.new_filename + '.pdf'
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                # Update the filename in the pdf_jobs table
                cur.execute("UPDATE document_chunks SET document_name = %s WHERE document_name = %s", (new_name, req.old_filename))
                cur.execute("UPDATE chat_messages SET filename = %s WHERE filename = %s", (new_name, req.old_filename))
                cur.execute("UPDATE pdf_jobs SET filename = %s WHERE filename = %s", (new_name, req.old_filename))
            conn.commit()
            
        old_path = f"uploads/{req.old_filename}"
        new_path = f"uploads/{new_name}"
        if os.path.exists(old_path):
            os.rename(old_path, new_path)
            
        return {"status": "success", "message": f"Renamed {req.old_filename} to {new_name}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
@app.delete("/delete-pdf/{filename}")
def delete_pdf(filename: str):
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM document_chunks WHERE document_name = %s", (filename,))
                cur.execute("DELETE FROM chat_messages WHERE filename = %s", (filename,))
                cur.execute("DELETE FROM pdf_jobs WHERE filename = %s", (filename,))
            conn.commit()
            
        file_path = f"uploads/{filename}"
        if os.path.exists(file_path):
            os.remove(file_path)
            
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    
#create new chat 
@app.delete("/clear-chat/{fiename}")
def clear_chat_history(filename: str):
    try:
        with get_db_connection() as conn: 
            with conn.cursor() as cur:
                cur.execute("DELETE FROM chat_messages WHERE filename = %s", (filename,))
                
            conn.commit()
        return {"status": "success", "message": f"Cleared chat history for {filename}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))