#!/bin/bash
# Debug script to diagnose startup issues

echo "=== DEBUG: Container Startup Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "=== Environment Variables ==="
echo "PUID: ${PUID:-not set}"
echo "PGID: ${PGID:-not set}"
echo "HOME: $HOME"
echo "USER: $USER"
echo ""

echo "=== Current User Info ==="
id
echo ""

echo "=== Existing Groups ==="
getent group | grep -E "(^users:|^appuser:|:100:|:99:)" || echo "No matching groups found"
echo ""

echo "=== Existing Users ==="
getent passwd | grep -E "(^nobody:|^appuser:|:99:|:100:)" || echo "No matching users found"
echo ""

echo "=== Directory Permissions ==="
ls -la / | grep -E "(app|input|output|cache|models)"
echo ""

echo "=== Testing Group Creation ==="
if getent group 100 > /dev/null 2>&1; then
    echo "Group with GID 100 exists:"
    getent group 100
else
    echo "Group with GID 100 does NOT exist"
fi

if getent group 99 > /dev/null 2>&1; then
    echo "Group with GID 99 exists:"
    getent group 99
else
    echo "Group with GID 99 does NOT exist"
fi
echo ""

echo "=== Testing User Modification ==="
echo "Current appuser info:"
id appuser 2>/dev/null || echo "appuser does not exist"
echo ""

echo "=== Python Environment ==="
which python
python --version
echo "PYTHONPATH: $PYTHONPATH"
echo ""

echo "=== ClipsAI Installation Check ==="
if [ -d "/app/clipsai_source" ]; then
    echo "ClipsAI source found at /app/clipsai_source"
    ls -la /app/clipsai_source | head -5
else
    echo "ERROR: ClipsAI source NOT found at /app/clipsai_source"
fi
echo ""

echo "=== Testing Python Import ==="
python -c "import sys; print('Python path:', sys.path[:3])" 2>&1
python -c "import clipsai; print('ClipsAI import successful')" 2>&1 || echo "ClipsAI import failed"
echo ""

echo "=== End of Diagnostics ==="