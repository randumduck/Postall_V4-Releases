#Requires -Version 5.1

$ImageName = "randumduck69/postall:v4-latest"
$ContainerName = "postall_app"
$VolumeName = "postall_data"
$MemoryLimit = "4g"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Postall_V4: Enterprise Content Platform" -ForegroundColor Cyan
Write-Host "   Automated Docker Installation and Boot" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting Postall_V4 pre-flight checks..." -ForegroundColor Cyan
Write-Host "The container will be allocated $MemoryLimit of memory and 2 CPUs for high-performance offline AI." -ForegroundColor Gray

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCommand) {
    Write-Host "Docker is not installed." -ForegroundColor Yellow
    $installDocker = Read-Host "Install Docker Desktop using winget now? (y/n)"
    if ($installDocker -notmatch "^[Yy]$") {
        Write-Host "Docker is required. Exiting." -ForegroundColor Red
        exit 1
    }

    $wingetCommand = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCommand) {
        Write-Host "winget is unavailable. Install Docker Desktop manually, then rerun this script." -ForegroundColor Red
        exit 1
    }

    winget install --exact --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker Desktop installation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "Docker Desktop was installed. Start it, wait for the daemon, then rerun this script." -ForegroundColor Yellow
    exit 0
}

Write-Host "Docker CLI found." -ForegroundColor Green
$null = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker daemon is not running or the current user cannot access it." -ForegroundColor Red
    Write-Host "Start Docker Desktop, wait for the engine to initialize, then rerun this script."
    exit 1
}

Write-Host "Pulling $ImageName..." -ForegroundColor Cyan
docker pull $ImageName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Image pull failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

$runApp = Read-Host "Run Postall_V4 now? (y/n)"
if ($runApp -notmatch "^[Yy]$") {
    Write-Host "Setup complete. Rerun this script when you are ready to start the app." -ForegroundColor Green
    exit 0
}

# Silent check using filter to avoid PowerShell stderr exceptions
$existingContainer = docker ps -a -q -f name="^${ContainerName}$"
if ($existingContainer) {
    $replaceContainer = Read-Host "A '$ContainerName' container exists. Replace it? This stops/removes the container but keeps persistent data. (y/n)"
    if ($replaceContainer -notmatch "^[Yy]$") {
        Write-Host "Existing container left unchanged." -ForegroundColor Yellow
        exit 0
    }

    docker rm -f $ContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Could not remove the existing container (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# Create named Docker volume to ensure full POSIX SQLite write compatibility and persistent local models
docker volume create $VolumeName | Out-Null

Write-Host "Launching Postall_V4 with volume '$VolumeName'..." -ForegroundColor Cyan

# Check for optional local .env configuration
$extraArgs = @()
if (Test-Path ".env") {
    Write-Host "Mounting host .env configuration into container..." -ForegroundColor Gray
    $extraArgs += "-v"
    $extraArgs += "${PWD}/.env:/app/.env"
}

docker run -d `
    --name $ContainerName `
    --publish 8000:8000 `
    --volume "${VolumeName}:/app/data" `
    @extraArgs `
    --memory="4g" `
    --memory-swap="4g" `
    --cpus="4.0" `
    --log-opt max-size=50m `
    --log-opt max-file=3 `
    --restart unless-stopped `
    $ImageName | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Container start failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Container '$ContainerName' is running with a $MemoryLimit memory limit." -ForegroundColor Green
$url = "http://localhost:8000"
Write-Host "Opening $url..." -ForegroundColor Cyan
try {
    Start-Process $url
}
catch {
    Write-Host "Could not launch a browser. Open $url manually." -ForegroundColor Yellow
}

exit 0
