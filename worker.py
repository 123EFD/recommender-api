import os
import time
import warnings
from dotenv import load_dotenv
from fastapi import HTTPException
import psycopg
import fitz
from langchain_text_splitters import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer
import camelot.io as camelot

#gs_bin_path = r'C:\Program Files\gs\gs10.06.0\bin'
#if gs_bin_path not in os.environ.get('PATH', ''):
#    os.environ['PATH'] += os.pathsep + gs_bin_path
    
load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL")

print("👨‍🍳 Chef is waking up... Warming up the AI ovens (Loading Models)...")
embedder = SentenceTransformer('all-MiniLM-L6-v2')
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=5000, 
    chunk_overlap=500, 
    separators=["\n\n", "\n", ".", " ", ""]
)
print("✅ Chef is ready and waiting for orders!")

def get_db_connection():
    if DATABASE_URL is None:
        raise ValueError("DATABASE_URL environment variable is not set in the .env file")
    return psycopg.connect(DATABASE_URL)

def process_pdf(filename):
    file_path = f"uploads/{filename}"
    chunks_with_pages = []
    
    try:
        #wait for saving file 
        time.sleep(1)
        
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("DELETE FROM document_chunks WHERE document_name = %s", (filename,))
            conn.commit()
        
        #2. Extract text using fitz pdf
        print(f"Processing PDF: {filename}...")
        with fitz.open(file_path) as doc:
            #3. READ PDF AND TRACK PAGES
            #enumerate allows i ndex number of the vector to be kept track with the text chunk
            for page_num, page in enumerate(doc.pages(), start=1):
                page_text = page.get_text()
                if not page_text.strip():
                    continue
                            
                for chunk in text_splitter.split_text(page_text):
                    chunks_with_pages.append(f"[Page {page_num}]\n{chunk}")
            
        #4. Extract tables from Camelot
        total_pages = doc.page_count
        
        if total_pages <= 50:
            
            print(f"Extracting tables from PDF: {filename}...")
            try:
                with warnings.catch_warnings():
                    warnings.simplefilter("ignore")
                    tables = camelot.read_pdf(file_path, pages='all', flavor='lattice')
                        
                for i, table in enumerate(tables):
                    df = table.df
                    if not df.empty:
                        #Convert table into Markdown
                        markdown_table = df.to_markdown(index=False)
                        chunks_with_pages.append(f"[Page {table.page} Table {i+1}]\n{markdown_table}")
                        
                print(f"✅ Found and parsed {len(tables)} tables perfectly!")
                    
            except Exception as table_err:
                print(f"⚠️ Table extraction skipped or failed: {table_err}")
                
        else:
            print(f"⚠️ Table extraction skipped for {filename} (too many pages: {total_pages})")
            
        if not chunks_with_pages:
            raise HTTPException(status_code=400, detail="No text or tables extracted from PDF")
                
        # Embed the annotated chunks
        print(f"Embedding {len(chunks_with_pages)} chunks into Vector Space...")
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
                        (filename, chunk_text, vector_string)
                    )
                
            conn.commit()
            
        return True
    
    except Exception as e:
        print(f"❌ Upload Error {filename}: {e}")
        return False
    
def init_jobs_db():
    print("Checking if the ticket rail (pdf_jobs table) exists...")
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS pdf_jobs (
                        filename TEXT PRIMARY KEY,
                        status TEXT NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
            conn.commit()
            print("✅ Ticket rail is ready!")
    except Exception as e:
        print(f"⚠️ Could not create jobs table: {e}")
    
#infinite loop for processing files
def start_worker():
    init_jobs_db()
    
    while True:
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        UPDATE pdf_jobs
                        SET status = 'processing'
                        WHERE filename = (
                            SELECT filename FROM pdf_jobs
                            WHERE status = 'pending'
                            LIMIT 1
                            FOR UPDATE SKIP LOCKED
                        )
                        RETURNING filename;        
                    """)
                    job = cur.fetchone()
                    
                conn.commit()
                
                if job:
                    filename = job[0]
                    print(f"🔔 DING! Order received: {filename}. Starting processing...")
                    
                    is_success = process_pdf(filename)
                    
                    final_status = 'completed' if is_success else 'failed'
                    with conn.cursor() as cur:
                        cur.execute(
                            "UPDATE pdf_jobs SET status = %s WHERE filename = %s",
                            (final_status, filename)
                        )
                    conn.commit()
                    print(f"🏁 Finished {filename}! Status updated to: {final_status}")
                    
                else:
                    time.sleep(2)  # Wait before checking for new jobs
                    
        except Exception as e:
            print(f"Worker encountered an error: {e}")
            time.sleep(5)  # Wait before retrying in case of an error

if __name__ == "__main__":
    start_worker()
                        
                        