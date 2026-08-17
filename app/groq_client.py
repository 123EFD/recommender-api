# app/groq_client.py
import os, httpx
from dotenv import load_dotenv

load_dotenv()
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
BASE_URL = "https://api.groq.com/openai/v1/chat/completions"

def groq_chat(system_prompt: str, user_message: str, model: str = "openai/gpt-oss-20b"):
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.2,
    }
    resp = httpx.post(BASE_URL, json=payload, headers={"Authorization": f"Bearer {GROQ_API_KEY}"})
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"]