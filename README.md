# OpenCue GUI Client

This directory contains files for setting up and running the OpenCue GUI client in a Docker container.

## Prerequisites

1. Docker installed and running
2. A running Cuebot server (see the cuebot-server directory)
3. For GUI mode (non-headless):
   - On Windows: An X server like VcXsrv or Xming
   - On Linux: X11 with proper permissions (`xhost +local:docker`)

## Setup and Usage

### Windows

Run the GUI client using PowerShell:

```powershell
.\start-cuegui.ps1 [options]
```

Options:
- `-CuebotHostname <hostname>`: Hostname or IP of the Cuebot server (default: opencue-cuebot)
- `-CuebotPort <port>`: Port on the Cuebot server (default: 8443)
- `-GuiName <name>`: Name for the GUI container (default: opencue-gui)
- `-Network <network>`: Docker network to connect to (default: cuebot-server_opencue-network)
- `-Build`: Build the Docker image locally instead of using pre-built
- `-Headless`: Run in headless mode (no GUI)
- `-Help`: Display help message

### Linux/macOS

Run the GUI client using Bash:

```bash
./start-cuegui.sh [options]
```

Options:
- `-c, --cuebot-hostname <hostname>`: Hostname or IP of the Cuebot server (default: opencue-cuebot)
- `-p, --cuebot-port <port>`: Port on the Cuebot server (default: 8443)
- `-g, --gui-name <name>`: Name for the GUI container (default: opencue-gui)
- `-n, --network <network>`: Docker network to connect to (default: cuebot-server_opencue-network)
- `-b, --build`: Build the Docker image locally
- `-l, --headless`: Run in headless mode (no GUI)
- `-h, --help`: Display help message

## Connecting to a Remote Cuebot

To connect to a Cuebot server running on a different machine:

1. Use the IP address or hostname of the remote machine:
   ```
   # Windows
   .\start-cuegui.ps1 -CuebotHostname 192.168.1.100
   
   # Linux/macOS
   ./start-cuegui.sh -c 192.168.1.100
   ```

2. Make sure the network settings allow communication between the machines.

## Launching the GUI

In non-headless mode, the GUI should launch automatically.

In headless mode, or if the GUI doesn't appear:
```
docker exec -it opencue-gui cuegui
```

## Using the GUI in Headless Mode

When running in headless mode, you need to pass the DISPLAY environment variable to connect to the GUI:

```powershell
# First, start the X server (VcXsrv or Xming) with "Disable access control" checked
$env:DISPLAY="host.docker.internal:0.0"  # Special hostname for Docker Desktop on Windows
# Or use your actual IP address
$env:DISPLAY="your.ip.address:0.0"

# Then run the GUI with the DISPLAY variable
docker exec -e DISPLAY=$env:DISPLAY -it opencue-gui cuegui
```

## Troubleshooting

### No GUI appears

1. Check if the X server is running and configured to allow connections
2. On Windows, make sure your firewall allows connections to the X server
3. Check container logs: `docker logs opencue-gui`

### Connection to Cuebot fails

1. Verify that the Cuebot server is running
2. Check network connectivity between containers or machines
3. Verify the correct hostname/IP and port are being used

### Missing NodeGraphQtPy module

If you see an error about the missing `NodeGraphQtPy` module:

```
ModuleNotFoundError: No module named 'NodeGraphQtPy'
```

This means the graph visualization dependency is missing. Rebuild the Docker image to include this dependency:

```
cd cuegui
docker build -t opencue/gui .
```

The included Dockerfile should already have this dependency installed.

## Building Custom Images

To build a custom GUI Docker image:

```
cd cuegui
docker build -t opencue/gui .
``` 