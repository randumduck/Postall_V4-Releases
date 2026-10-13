#Requires -Version 5.1

$ImageName = "randumduck69/postall:v4-latest"
$ContainerName = "postall_engine"
$VolumeName = "postall_data"
$NetworkName = "postall_mesh"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   POSTALL: One For All — All For One    " -ForegroundColor Cyan
Write-Host "   Automated Docker Installation & Boot   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting Postall pre-flight checks..." -ForegroundColor Cyan
Write-Host "Adaptive allocation: 4 GB baseline reservation with 6 GB burst capacity." -ForegroundColor Gray

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
    Write-Host "Docker daemon is not running or current user lacks permissions." -ForegroundColor Red
    Write-Host "Start Docker Desktop, wait for the engine to initialize, then rerun this script."
    exit 1
}

Write-Host "Pulling $ImageName..." -ForegroundColor Cyan
docker pull $ImageName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Image pull failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

$runApp = Read-Host "Run Postall now? (y/n)"
if ($runApp -notmatch "^[Yy]$") {
    Write-Host "Setup complete. Rerun this script when you are ready to start the app." -ForegroundColor Green
    exit 0
}

# 1. Ensure shared mesh network exists
docker network inspect $NetworkName 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    docker network create $NetworkName | Out-Null
}

# 2. Handle existing engine container
$existingContainer = docker ps -a -q -f name="^${ContainerName}$"
if ($existingContainer) {
    $replaceContainer = Read-Host "A '$ContainerName' container exists. Replace it? This preserves persistent database volume. (y/n)"
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

# 3. Create persistent data volume
docker volume create $VolumeName | Out-Null

Write-Host "Configuring container storage and credentials..." -ForegroundColor Cyan

# 4. Detect optional host .env and keys directories
$extraArgs = @()
if (Test-Path ".env") {
    Write-Host "Mounting host .env configuration into container..." -ForegroundColor Gray
    $extraArgs += "-v"
    $extraArgs += "${PWD}/.env:/app/.env"
}
if (Test-Path "keys") {
    Write-Host "Mounting host keys directory for Gateway RS256 signature sync..." -ForegroundColor Gray
    $extraArgs += "-v"
    $extraArgs += "${PWD}/keys:/app/keys"
}

# 5. Launch container
docker run -d `
    --name $ContainerName `
    --network $NetworkName `
    --publish 8000:8000 `
    --volume "${VolumeName}:/app/data" `
    @extraArgs `
    --memory-reservation="4g" `
    --memory="6g" `
    --memory-swap="6g" `
    --log-opt max-size=50m `
    --log-opt max-file=3 `
    --restart unless-stopped `
    $ImageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "Container start failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Container '$ContainerName' is running on '$NetworkName' with 4GB-6GB adaptive RAM." -ForegroundColor Green
$url = "http://localhost:8000"
Write-Host "Opening $url..." -ForegroundColor Cyan
try {
    Start-Process $url
}
catch {
    Write-Host "Could not launch browser automatically. Open $url manually." -ForegroundColor Yellow
}

exit 0
