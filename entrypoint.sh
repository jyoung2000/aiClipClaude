#!/bin/bash
set -e

# Handle unRAID permissions
PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "Starting with UID: $PUID and GID: $PGID"

# Create group if it doesn't exist
if ! getent group $PGID > /dev/null 2>&1; then
    groupadd -g $PGID appgroup
fi

# Modify user if needed
if [ "$PUID" != "1000" ] || [ "$PGID" != "1000" ]; then
    usermod -u $PUID appuser
    groupmod -g $PGID appuser
    usermod -g $PGID appuser
fi

# Ensure proper ownership of directories
chown -R $PUID:$PGID /app /input /output /cache /models

# Create necessary subdirectories
mkdir -p /cache/.clipsai /output/clips /input/uploads
chown -R $PUID:$PGID /cache/.clipsai /output/clips /input/uploads

# Export environment variables
export HOME=/app
export PYTHONPATH=/app/clipsai_source:$PYTHONPATH

# Handle HuggingFace token if provided
if [ ! -z "$HUGGINGFACE_TOKEN" ]; then
    echo "Setting HuggingFace token..."
    export HF_TOKEN=$HUGGINGFACE_TOKEN
fi

# Execute command as appuser
exec gosu $PUID:$PGID "$@"