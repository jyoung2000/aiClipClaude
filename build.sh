#!/bin/bash
# Build script for aiClipClaude Docker container

echo "🚀 Building aiClipClaude Docker container..."

# Check if docker compose exists
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Error: Docker Compose not found!"
    echo "Please install Docker Desktop or Docker Compose"
    exit 1
fi

# Build the container
echo "📦 Building container with: $COMPOSE_CMD build"
$COMPOSE_CMD build

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo ""
    echo "To run the container:"
    echo "  $COMPOSE_CMD up -d"
    echo ""
    echo "To view logs:"
    echo "  $COMPOSE_CMD logs -f"
    echo ""
    echo "Access the web interface at:"
    echo "  http://localhost:4444"
else
    echo "❌ Build failed!"
    exit 1
fi