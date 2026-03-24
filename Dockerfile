# Use a lightweight Python Linux environment
FROM python:3.10-slim

# Install system dependencies needed for Camelot, OpenCV, and general compiling
RUN apt-get update && apt-get install -y \
    ghostscript \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Hugging Face requires apps to run as a non-root user for security
RUN useradd -m -u 1000 user
USER user
ENV PATH="/home/user/.local/bin:$PATH"

# Set the working directory
WORKDIR /app

# Copy your files into the container
COPY --chown=user . /app

# Make the startup script executable
RUN chmod +x start.sh

# Upgrade pip and install basic Python build tools
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install Python packages (Forcing the CPU-only version of PyTorch to save RAM!)
RUN pip install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu

# Create the uploads folder just in case
RUN mkdir -p uploads

# Expose the Hugging Face port
EXPOSE 7860

# Run the startup script!
CMD ["./start.sh"]