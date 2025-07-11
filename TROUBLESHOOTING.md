# Troubleshooting Guide

## Container Restart Loop

If your container is stuck in a restart loop, follow these steps:

### 1. Check Container Logs

First, check what error is causing the restart:

```bash
docker logs aiClipClaude
# or
docker compose logs clipsai
```

### 2. Run Debug Diagnostics

We've included a debug script to help identify issues:

```bash
# Run the debug container
docker compose -f docker-compose.debug.yml up

# This will output diagnostic information about:
# - User/Group configurations
# - Directory permissions
# - Python environment
# - ClipsAI installation status
```

### 3. Common Issues and Solutions

#### GID 100 Already Exists

**Symptom**: Error message about "groupadd: GID '100' already exists"

**Solution**: The container now handles this gracefully. If you still see issues:

1. Check if GID 100 is the 'users' group on your system:
   ```bash
   getent group 100
   ```

2. If needed, you can use a different GID:
   ```yaml
   environment:
     - PUID=99
     - PGID=1000  # Use a different GID
   ```

#### Permission Denied Errors

**Symptom**: Cannot create directories or write files

**Solution**: Ensure the host directories have proper permissions:

```bash
# Create directories with proper permissions
mkdir -p input output cache models
chmod 777 input output cache models
```

#### Python Import Errors

**Symptom**: "ModuleNotFoundError: No module named 'clipsai'"

**Solution**: The ClipsAI source might not be properly installed. Rebuild the container:

```bash
docker compose build --no-cache
```

### 4. Manual Container Access

To debug inside the container:

```bash
# Start container with bash shell
docker run -it --rm \
  -e PUID=99 \
  -e PGID=100 \
  --entrypoint /bin/bash \
  aiclipClaude

# Inside container, test the startup process
/app/entrypoint.sh python /app/web_app.py
```

### 5. Alternative Configurations

#### Using Root User (Not Recommended for Production)

If permissions continue to be problematic, you can temporarily run as root:

```yaml
environment:
  - PUID=0
  - PGID=0
```

#### Using Your User's UID/GID

Find your user's UID and GID:

```bash
id -u  # Your UID
id -g  # Your GID
```

Then use these values:

```yaml
environment:
  - PUID=1000  # Your UID
  - PGID=1000  # Your GID
```

### 6. Verify Container Health

Once running, verify the container is healthy:

```bash
# Check if web interface is accessible
curl -I http://localhost:4444

# Check container status
docker ps -a | grep aiClipClaude
```

### 7. Rebuild from Scratch

If all else fails, completely rebuild:

```bash
# Stop and remove container
docker compose down

# Remove old image
docker rmi aiclipClaude

# Rebuild
docker compose build --no-cache

# Start fresh
docker compose up -d
```

## Other Common Issues

### Web Interface Not Loading

1. Check if port 4444 is already in use:
   ```bash
   netstat -tulpn | grep 4444
   ```

2. Try a different port in docker-compose.yml:
   ```yaml
   ports:
     - "5555:4444"  # Use port 5555 instead
   ```

### Out of Memory

Adjust memory limits in docker-compose.yml:

```yaml
deploy:
  resources:
    limits:
      memory: 16G  # Increase if needed
```

### Slow Processing

CPU-only processing is inherently slower. To improve:

1. Reduce video resolution before processing
2. Process shorter videos
3. Reduce the number of clips requested

## Getting Help

If you continue to experience issues:

1. Run the debug diagnostics and save the output
2. Check the container logs
3. Open an issue on GitHub with:
   - Your system details (OS, Docker version)
   - The complete error messages
   - Output from the debug script