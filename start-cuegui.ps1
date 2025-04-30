# OpenCue GUI Client Setup Script for Windows

# Parse command line arguments
param (
    [string]$CuebotHostname = "opencue-cuebot",
    [string]$CuebotPort = "8443",
    [string]$GuiName = "opencue-gui",
    [string]$Network = "cuebot-server_opencue-network",
    [switch]$Build,
    [switch]$Headless,
    [switch]$Help
)

# Display help if requested
if ($Help) {
    Write-Host "Usage: .\start-gui.ps1 [-CuebotHostname <hostname or IP>] [-CuebotPort <port>] [-GuiName <GUI container name>] [-Network <docker network>] [-Build] [-Headless] [-Help]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -CuebotHostname    The hostname or IP address of the Cuebot server (default: opencue-cuebot)"
    Write-Host "                     - For same-machine containers: use 'opencue-cuebot' (default)"
    Write-Host "                     - For different machines: use the actual IP address or hostname"
    Write-Host "  -CuebotPort        The port to connect to on the Cuebot server (default: 8443)"
    Write-Host "  -GuiName           The name to give to the GUI container (default: opencue-gui)"
    Write-Host "  -Network           Docker network to connect to (default: cuebot-server_opencue-network)"
    Write-Host "  -Build             Build the Docker image locally instead of using pre-built"
    Write-Host "  -Headless          Run in headless mode (no GUI, use 'docker exec' to launch GUI later)"
    Write-Host "  -Help              Display this help message"
    exit 0
}

# Check if Docker is installed and running
try {
    docker info | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running"
    }
}
catch {
    Write-Host "Error: Docker is not installed or not running."
    Write-Host "Please install Docker Desktop for Windows and start it before running this script."
    exit 1
}

# Check if X server is available in path (for GUI functionality)
if (-not $Headless) {
    $xServerFound = $false
    try {
        if (Get-Command vcxsrv -ErrorAction SilentlyContinue) {
            $xServerFound = $true
        } elseif (Get-Command xming -ErrorAction SilentlyContinue) {
            $xServerFound = $true
        } elseif (Test-Path "C:\Program Files\VcXsrv\vcxsrv.exe") {
            $xServerFound = $true
        } elseif (Test-Path "C:\Program Files (x86)\Xming\Xming.exe") {
            $xServerFound = $true
        }
    } catch {
        # Command not found, it's ok we'll warn
    }

    if (-not $xServerFound) {
        Write-Host "Warning: No X server found in PATH. For GUI functionality, install VcXsrv or Xming."
        Write-Host "Running in headless mode. You can connect later with docker exec -it $GuiName cuegui"
        $Headless = $true
    }
}

# Check if the specified Docker network exists
$networkExists = $false
try {
    $networkInfo = docker network inspect $Network 2>&1
    if ($LASTEXITCODE -eq 0) {
        $networkExists = $true
    }
}
catch {
    # Network doesn't exist, which is a problem
}

if (-not $networkExists) {
    Write-Host "Error: Docker network '$Network' doesn't exist."
    Write-Host "Please make sure your Cuebot services are running first."
    Write-Host "Possible networks available:"
    docker network ls
    exit 1
}

# Combine hostname and port for CUEBOT_HOSTS
$CuebotHosts = "${CuebotHostname}:${CuebotPort}"

# Print configuration summary
Write-Host "OpenCue GUI Configuration Summary:"
Write-Host "=================================="
Write-Host "Cuebot Hosts: $CuebotHosts"
Write-Host "GUI Container Name: $GuiName"
Write-Host "Docker Network: $Network"
Write-Host "Headless Mode: $Headless"
Write-Host ""

# Build the Docker image if requested
if ($Build) {
    Write-Host "Building OpenCue GUI Docker image..."
    docker build -t opencue/gui ./
}

# Check if the GUI container already exists
$containerExists = $false
try {
    $containerInfo = docker container inspect $GuiName 2>&1
    if ($LASTEXITCODE -eq 0) {
        $containerExists = $true
    }
}
catch {
    # Container doesn't exist, which is fine
}

if ($containerExists) {
    Write-Host "GUI container '$GuiName' already exists."
    
    # Check if the container is running
    $containerRunning = docker ps -q -f "name=$GuiName"
    
    if ($containerRunning) {
        Write-Host "GUI container is already running."
    }
    else {
        Write-Host "Starting existing GUI container..."
        docker start $GuiName
    }
}
else {
    # Create a shared directory for the GUI
    $GuiSharedDir = Join-Path $env:USERPROFILE "opencue-gui"
    if (-not (Test-Path $GuiSharedDir)) {
        Write-Host "Creating GUI shared directory at $GuiSharedDir..."
        New-Item -ItemType Directory -Path $GuiSharedDir | Out-Null
    }

    # Format the path for Docker on Windows
    $volumeMount = "$($GuiSharedDir -replace '\\', '/' -replace ':', ''):/opencue/shared"
    
    # Get the IP of the host machine for X11 display
    $hostIp = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet*,WiFi*,Ethernet,Wi-Fi | Where-Object { $_.IPAddress -notmatch '127\.0\.0\.1' -and $_.IPAddress -notmatch '169\.254\.' } | Select-Object -First 1).IPAddress
    if (-not $hostIp) {
        $hostIp = "127.0.0.1"
    }
    
    # Run the GUI container
    Write-Host "Starting GUI container..."
    
    if ($Headless) {
        # Headless mode - no X11 forwarding
        docker run -d --name $GuiName `
            --network $Network `
            --env CUEBOT_HOSTS=$CuebotHosts `
            --volume "/$volumeMount" `
            opencue/gui
    } else {
        # GUI mode with X11 forwarding
        docker run -d --name $GuiName `
            --network $Network `
            --env CUEBOT_HOSTS=$CuebotHosts `
            --env DISPLAY="${hostIp}:0.0" `
            --volume "/$volumeMount" `
            opencue/gui "/opencue/start.sh" "gui"
    }
}

# Verify the container is running
$containerRunning = docker ps -q -f "name=$GuiName"
if ($containerRunning) {
    Write-Host "GUI container is now running."
    
    # Display the logs
    Write-Host "GUI container logs:"
    Write-Host "=================="
    docker logs $GuiName
    
    if (-not $Headless) {
        Write-Host ""
        Write-Host "If you don't see the GUI, make sure your X server is running and allows connections."
        Write-Host "You can also connect to the container using: docker exec -it $GuiName cuegui"
    }
}
else {
    Write-Host "Error: Failed to start GUI container."
    Write-Host "Check Docker logs for more information:"
    Write-Host "docker logs $GuiName"
    exit 1
}

Write-Host ""
Write-Host "OpenCue GUI setup complete!"
Write-Host "To stop the GUI container, run: docker stop $GuiName"
Write-Host "To view GUI logs, run: docker logs $GuiName"
Write-Host "To run the GUI explicitly, run: docker exec -it $GuiName cuegui" 