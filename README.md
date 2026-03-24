# 🧠 Educational AI Study Suite & Recommender API

An enterprise-grade, full-stack AI application designed to analyze student performance risk and provide an interactive, real-time RAG (Retrieval-Augmented Generation) workspace for university course materials. 

This repository contains both the **FastAPI Backend** (The Engine) and the **Flutter Web Frontend** (The Workspace), decoupled for maximum scalability and performance.

---

## 🏗️ Tech Stack & Architecture

This project is built using a decoupled microservice architecture, allowing the heavy Machine Learning background tasks to operate independently from the lightning-fast web server.

### **Frontend (The Workspace)**
* **Framework:** Flutter (compiled to Web)
* **Renderer:** CanvasKit (for high-performance UI and PDF rendering)
* **Key Libraries:** `syncfusion_flutter_pdfviewer`, `flutter_markdown`, `http`
* **Deployment:** Vercel

### **Backend (The Engine)**
* **Framework:** FastAPI (Python)
* **Database:** PostgreSQL (Hosted on Neon) with `pgvector` for semantic search
* **Background Jobs:** Python native multi-threading/processing (`worker.py`)
* **Deployment:** Hugging Face Spaces (Dockerized Linux Container)

### **AI & Machine Learning**
* **LLM Provider:** Groq (Llama-3.3-70b-versatile for reasoning, Llama-3.1-8b-instant for fast tasks)
* **Embeddings:** `all-MiniLM-L6-v2` (SentenceTransformers)
* **Re-Ranking:** `ms-marco-MiniLM-L-6-v2` (CrossEncoder)
* **Predictive Model:** Custom PyTorch Multi-Layer Perceptron (MLP) for student risk analysis
* **PDF Processing:** PyMuPDF (`fitz`), Camelot, `langchain_text_splitters`

---

## ✨ Key Features

1.  **Real-Time Streaming AI Chat:** Talk to your textbooks. The UI utilizes Server-Sent Events (SSE) to stream markdown-formatted text word-by-word, exactly like ChatGPT.
2.  **Hybrid RAG Search:** Combines Vector Similarity Search (`<=>`) with Keyword Search (`ts_rank`) and a Cross-Encoder to find the most accurate textbook excerpts.
3.  **Decoupled PDF Processing:** Uploading massive PDFs won't freeze the app. A state-machine job queue handles PDF chunking and embedding in the background.
4.  **Student Risk Predictor:** A PyTorch model evaluates student habits (attendance, prep, gaming) alongside grades to flag burnout risks and auto-fetch YouTube tutorials and web articles for struggling subjects.
5.  **Conversational Memory:** The PostgreSQL database securely remembers chat histories for every individual document.

---

## 🚀 Local Setup & Installation

### Prerequisites
* Python 3.10+
* Flutter SDK (Stable channel)
* PostgreSQL Database URL (e.g., Neon)

### 1. Backend Setup (FastAPI)
1. Navigate to the root directory.
2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   # Windows: .\venv\Scripts\activate
   # Mac/Linux: source venv/bin/activate
