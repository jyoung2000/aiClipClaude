#!/bin/bash
set -e

# Handle unRAID permissions
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with UID: $PUID and GID: $PGID"

# Check if we need to modify the user/group
if [ "$PUID" != "1000" ] || [ "$PGID" != "1000" ]; then
    # Check if group exists, if not create it
    if ! getent group $PGID > /dev/null 2>&1; then
        echo "Creating group with GID $PGID"
        groupadd -g $PGID appgroup
    else
        echo "Group with GID $PGID already exists"
    fi
    
    # Get the group name for the GID
    GROUP_NAME=$(getent group $PGID | cut -d: -f1)
    
    # Modify user
    echo "Modifying user appuser to UID $PUID and GID $PGID"
    usermod -u $PUID appuser 2>/dev/null || echo "User already has UID $PUID"
    usermod -g $GROUP_NAME appuser 2>/dev/null || echo "User already in group $GROUP_NAME"
fi

# Ensure proper ownership of directories
echo "Setting directory permissions..."
chown -R $PUID:$PGID /app /input /output /cache /models 2>/dev/null || true

# Create necessary subdirectories
mkdir -p /cache/.clipsai /output/clips /input/uploads 2>/dev/null || true
chown -R $PUID:$PGID /cache/.clipsai /output/clips /input/uploads 2>/dev/null || true

# Export environment variables
export HOME=/app
export PYTHONPATH=/app/clipsai_source:$PYTHONPATH

# Handle HuggingFace token if provided
if [ ! -z "$HUGGINGFACE_TOKEN" ]; then
    echo "Setting HuggingFace token..."
    export HF_TOKEN=$HUGGINGFACE_TOKEN
fi

echo "Starting application..."

# Execute command as specified user
exec gosu $PUID:$PGID "$@"