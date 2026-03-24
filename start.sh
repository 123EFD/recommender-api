#!/bin/bash

# 1. Start the Chef (worker.py) in the background (the & symbol does this)
python worker.py &

# 2. Start the Waiter (FastAPI) in the foreground. 
# Hugging Face strictly requires web apps to run on port 7860.
uvicorn main:app --host 0.0.0.0 --port 7860