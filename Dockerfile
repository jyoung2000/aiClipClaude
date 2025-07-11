# Multi-stage build for ClipsAI with Web GUI
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install poetry for dependency management
RUN pip install poetry

# Copy ClipsAI source
WORKDIR /build
RUN git clone https://github.com/ClipsAI/clipsai.git .

# Install ClipsAI dependencies
RUN poetry config virtualenvs.create false
RUN poetry install --no-dev

# Final stage
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    gosu \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user and directories
RUN useradd -m -u 1000 -s /bin/bash appuser

# Set up directories with proper permissions
RUN mkdir -p /app /input /output /cache /models && \
    chown -R appuser:appuser /app /input /output /cache /models

# Copy Python packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy ClipsAI source
COPY --from=builder /build /app/clipsai_source

WORKDIR /app

# Install additional dependencies for web GUI and CPU-only PyTorch
RUN pip install --no-cache-dir \
    gradio==4.19.2 \
    torch==2.1.2+cpu torchvision==0.16.2+cpu torchaudio==2.1.2+cpu -f https://download.pytorch.org/whl/torch_stable.html \
    whisperx@git+https://github.com/m-bain/whisperx.git \
    pyannote.audio \
    python-multipart \
    aiofiles \
    asyncio \
    python-dotenv

# Copy application files
COPY web_app.py /app/
COPY entrypoint.sh /app/
COPY requirements-web.txt /app/

# Install web-specific requirements
RUN pip install --no-cache-dir -r requirements-web.txt

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Set environment variables
ENV PYTHONPATH=/app/clipsai_source:$PYTHONPATH
ENV GRADIO_SERVER_NAME=0.0.0.0
ENV GRADIO_SERVER_PORT=4444
ENV TORCH_HOME=/models
ENV HF_HOME=/models
ENV TRANSFORMERS_CACHE=/models

# Expose port
EXPOSE 4444

# Volume mounts
VOLUME ["/input", "/output", "/cache", "/models"]

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "/app/web_app.py"]