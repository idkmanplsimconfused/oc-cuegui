#!/bin/bash
# OpenCue GUI Client Setup Script for Linux

# Default values
CUEBOT_HOSTNAME="opencue-cuebot"
CUEBOT_PORT="8443"
GUI_NAME="opencue-gui"
NETWORK="cuebot_opencue-network"
BUILD=false
HEADLESS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--cuebot-hostname)
      CUEBOT_HOSTNAME="$2"
      shift 2
      ;;
    -p|--cuebot-port)
      CUEBOT_PORT="$2"
      shift 2
      ;;
    -g|--gui-name)
      GUI_NAME="$2"
      shift 2
      ;;
    -n|--network)
      NETWORK="$2"
      shift 2
      ;;
    -b|--build)
      BUILD=true
      shift
      ;;
    -l|--headless)
      HEADLESS=true
      shift
      ;;
    -h|--help)
      echo "Usage: ./start-gui.sh [options]"
      echo ""
      echo "Options:"
      echo "  -c, --cuebot-hostname <hostname>  The hostname or IP address of the Cuebot server (default: opencue-cuebot)"
      echo "                                     - For same-machine containers: use 'opencue-cuebot' (default)"
      echo "                                     - For different machines: use the actual IP address or hostname"
      echo "  -p, --cuebot-port <port>          The port to connect to on the Cuebot server (default: 8443)"
      echo "  -g, --gui-name <name>             The name to give to the GUI container (default: opencue-gui)"
      echo "  -n, --network <network>           Docker network to connect to (default: cuebot_opencue-network)"
      echo "  -b, --build                       Build the Docker image locally instead of using pre-built"
      echo "  -l, --headless                    Run in headless mode (no GUI, use 'docker exec' to launch GUI later)"
      echo "  -h, --help                        Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    echo "Please install Docker and start it before running this script."
    exit 1
fi

# Check if the Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running."
    echo "Please start the Docker service before running this script."
    exit 1
fi

# Check if X server is available in path (for GUI functionality)
if [ "$HEADLESS" = false ] && [ -z "$DISPLAY" ]; then
    echo "Warning: No X server detected (DISPLAY environment variable not set)."
    echo "Running in headless mode. You can connect later with docker exec -it $GUI_NAME cuegui"
    HEADLESS=true
fi

# Check if the specified Docker network exists
if ! docker network inspect "$NETWORK" &> /dev/null; then
    echo "Error: Docker network '$NETWORK' doesn't exist."
    echo "Please make sure your Cuebot services are running first."
    echo "Possible networks available:"
    docker network ls
    exit 1
fi

# Combine hostname and port for CUEBOT_HOSTS
CUEBOT_HOSTS="${CUEBOT_HOSTNAME}:${CUEBOT_PORT}"

# Print configuration summary
echo "OpenCue GUI Configuration Summary:"
echo "=================================="
echo "Cuebot Hosts: $CUEBOT_HOSTS"
echo "GUI Container Name: $GUI_NAME"
echo "Docker Network: $NETWORK"
echo "Headless Mode: $HEADLESS"
echo ""

# Build the Docker image if requested
if [ "$BUILD" = true ]; then
    echo "Building OpenCue GUI Docker image..."
    docker build -t opencue/gui ./
fi

# Check if the GUI container already exists
if docker container inspect "$GUI_NAME" &> /dev/null; then
    echo "GUI container '$GUI_NAME' already exists."
    
    # Check if the container is running
    if docker ps -q -f "name=$GUI_NAME" &> /dev/null; then
        echo "GUI container is already running."
    else
        echo "Starting existing GUI container..."
        docker start "$GUI_NAME"
    fi
else
    # Create a shared directory for the GUI
    GUI_SHARED_DIR="$HOME/opencue-gui"
    if [ ! -d "$GUI_SHARED_DIR" ]; then
        echo "Creating GUI shared directory at $GUI_SHARED_DIR..."
        mkdir -p "$GUI_SHARED_DIR"
    fi
    
    # Run the GUI container
    echo "Starting GUI container..."
    
    if [ "$HEADLESS" = true ]; then
        # Headless mode - no X11 forwarding
        docker run -d --name "$GUI_NAME" \
            --network "$NETWORK" \
            --env CUEBOT_HOSTS="$CUEBOT_HOSTS" \
            --volume "$GUI_SHARED_DIR:/opencue/shared" \
            opencue/gui
    else
        # GUI mode with X11 forwarding
        docker run -d --name "$GUI_NAME" \
            --network "$NETWORK" \
            --env CUEBOT_HOSTS="$CUEBOT_HOSTS" \
            --env DISPLAY="$DISPLAY" \
            --volume "/tmp/.X11-unix:/tmp/.X11-unix" \
            --volume "$GUI_SHARED_DIR:/opencue/shared" \
            opencue/gui "gui"
    fi
fi

# Verify the container is running
if docker ps -q -f "name=$GUI_NAME" &> /dev/null; then
    echo "GUI container is now running."
    
    # Display the logs
    echo "GUI container logs:"
    echo "=================="
    docker logs "$GUI_NAME"
    
    if [ "$HEADLESS" = false ]; then
        echo ""
        echo "If you don't see the GUI, try to run it manually with: docker exec -it $GUI_NAME cuegui"
    fi
else
    echo "Error: Failed to start GUI container."
    echo "Check Docker logs for more information:"
    echo "docker logs $GUI_NAME"
    exit 1
fi

echo ""
echo "OpenCue GUI setup complete!"
echo "To stop the GUI container, run: docker stop $GUI_NAME"
echo "To view GUI logs, run: docker logs $GUI_NAME"
echo "To run the GUI explicitly, run: docker exec -it $GUI_NAME cuegui"

if [ "$HEADLESS" = true ]; then
    echo ""
    echo "Since you're running in headless mode, use the following to connect with GUI:"
    echo "    DISPLAY=:0 docker exec -e DISPLAY=\$DISPLAY -it $GUI_NAME cuegui"
fi 