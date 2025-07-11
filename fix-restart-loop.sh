#!/bin/bash
# Fix script for Docker restart loop issues

echo "🔧 Fixing aiClipClaude Docker container restart loop..."

# Stop the container if running
echo "Stopping container..."
docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true

# Clean up old containers and images
echo "Cleaning up old containers..."
docker rm -f aiClipClaude 2>/dev/null || true

# Pull latest changes from GitHub
echo "Pulling latest fixes from GitHub..."
git pull origin main || {
    echo "⚠️  Not a git repository. Downloading fixed files directly..."
    
    # Download fixed entrypoint.sh
    curl -L https://raw.githubusercontent.com/jyoung2000/aiClipClaude/main/entrypoint.sh > entrypoint.sh
    chmod +x entrypoint.sh
    
    # Download fixed docker-compose.yml
    curl -L https://raw.githubusercontent.com/jyoung2000/aiClipClaude/main/docker-compose.yml > docker-compose.yml
}

# Rebuild the image with no cache to ensure fixes are applied
echo "Rebuilding Docker image with fixes..."
docker compose build --no-cache || docker-compose build --no-cache

# Start the container
echo "Starting container..."
docker compose up -d || docker-compose up -d

# Wait a moment
sleep 5

# Check status
echo ""
echo "📊 Container status:"
docker ps --filter name=aiClipClaude --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📋 Recent logs:"
docker compose logs --tail=20 || docker-compose logs --tail=20

echo ""
echo "✅ Fix applied! The container should now start without the GID conflict."
echo "Access the web interface at: http://localhost:4444"