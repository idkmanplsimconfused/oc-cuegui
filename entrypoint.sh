#!/bin/bash
set -e

echo "Starting OpenCue GUI container..."
echo "CUEBOT_HOSTS=$CUEBOT_HOSTS"
echo "DISPLAY=$DISPLAY"

# Execute the command passed to docker run
exec "$@" 