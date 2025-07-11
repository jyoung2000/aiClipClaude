# ClipsAI Docker container with Web GUI
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    gosu \
    curl \
    build-essential \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Create app user and directories
RUN useradd -m -u 1000 -s /bin/bash appuser

# Set up directories with proper permissions
RUN mkdir -p /app /input /output /cache /models && \
    chown -R appuser:appuser /app /input /output /cache /models

WORKDIR /app

# Install CPU-only PyTorch first
RUN pip install --no-cache-dir \
    torch==2.1.2+cpu \
    torchvision==0.16.2+cpu \
    torchaudio==2.1.2+cpu \
    -f https://download.pytorch.org/whl/torch_stable.html

# Install sentence-transformers for BERT embeddings
RUN pip install --no-cache-dir sentence-transformers

# Clone and install ClipsAI
RUN git clone https://github.com/ClipsAI/clipsai.git /app/clipsai_source && \
    cd /app/clipsai_source && \
    pip install --no-cache-dir -e .

# Install WhisperX with its dependencies
RUN pip install --no-cache-dir git+https://github.com/m-bain/whisperx.git

# Install additional dependencies for web GUI
RUN pip install --no-cache-dir \
    gradio==4.19.2 \
    pyannote.audio \
    python-multipart \
    aiofiles \
    python-dotenv \
    moviepy==1.0.3 \
    pydub==0.25.1 \
    webrtcvad==2.0.10 \
    srt==3.5.3 \
    colorlog==6.8.0 \
    faster-whisper

# Copy application files
COPY web_app.py /app/
COPY entrypoint.sh /app/

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV PYTHONPATH=/app/clipsai_source:$PYTHONPATH
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=4444
ENV TORCH_HOME=/models
ENV HF_HOME=/models
ENV TRANSFORMERS_CACHE=/models
ENV TOKENIZERS_PARALLELISM=false

# Expose port
EXPOSE 4444

# Volume mounts
VOLUME ["/input", "/output", "/cache", "/models"]

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "/app/web_app.py"]