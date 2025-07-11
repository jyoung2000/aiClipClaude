#!/bin/bash
# Test script for aiClipClaude Docker container

echo "🧪 Testing aiClipClaude container..."

# Check if container is running
if docker ps | grep -q aiClipClaude; then
    echo "✅ Container is running"
else
    echo "❌ Container is not running. Starting it..."
    docker compose up -d
    sleep 10
fi

# Test web interface
echo "🌐 Testing web interface..."
response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4444)

if [ "$response" = "200" ]; then
    echo "✅ Web interface is accessible at http://localhost:4444"
else
    echo "❌ Web interface returned HTTP $response"
    echo "   Checking logs..."
    docker compose logs --tail=50
fi

# Check container health
echo "🏥 Checking container health..."
health=$(docker inspect --format='{{.State.Health.Status}}' aiClipClaude 2>/dev/null)

if [ "$health" = "healthy" ]; then
    echo "✅ Container is healthy"
elif [ "$health" = "unhealthy" ]; then
    echo "❌ Container is unhealthy"
    docker compose logs --tail=50
else
    echo "⚠️  No health check configured or still starting"
fi

# Display container info
echo ""
echo "📊 Container Info:"
docker ps --filter name=aiClipClaude --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📁 Volume Mounts:"
docker inspect aiClipClaude --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' 2>/dev/null

echo ""
echo "🔍 To view logs: docker compose logs -f"
echo "🛑 To stop: docker compose down"