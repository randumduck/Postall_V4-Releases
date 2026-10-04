Write-Host "🚀 Starting Postall_V4 Pre-flight checks..." -ForegroundColor Cyan

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "⚠️ Docker is not installed." -ForegroundColor Yellow
    $installDocker = Read-Host "Do you want to install Docker Desktop via winget? (y/n)"
    if ($installDocker -match "^[Yy]$") {
        Write-Host "Installing Docker Desktop..." -ForegroundColor Cyan
        winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
        Write-Host "✅ Docker Desktop installed. Please start it from your Start Menu." -ForegroundColor Green
        Write-Host "Restart this PowerShell window after Docker starts." -ForegroundColor Yellow
        exit
    } else {
        Write-Host "❌ Docker is required to continue. Exiting." -ForegroundColor Red
        exit
    }
} else {
    Write-Host "✅ Docker is already installed." -ForegroundColor Green
}

try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "❌ Docker daemon is not running. Please start Docker Desktop and try again." -ForegroundColor Red
    exit
}

$ImageName = "randumduck69/postall:v4-latest"
Write-Host "📥 Pulling the latest Postall_V4 image..." -ForegroundColor Cyan
docker pull $ImageName

$runApp = Read-Host "✅ Image pulled successfully. Do you want to run Postall_V4 now? (y/n)"
if ($runApp -match "^[Yy]$") {
    Write-Host "⚙️ Starting Postall_V4 with a strict 2.5 GB memory limit..." -ForegroundColor Cyan
    docker volume create postall_data | Out-Null
    docker rm -f postall_app 2>&1 | Out-Null
    
    docker run -d `
        --name postall_app `
        -p 8000:8000 `
        -v postall_data:/app/data `
        -m 2500M `
        --restart unless-stopped `
        $ImageName | Out-Null
        
    Write-Host "✅ Container 'postall_app' is securely running in the background." -ForegroundColor Green
    $Url = "http://localhost:8000"
    Write-Host "🌐 Opening $Url in your default web browser..." -ForegroundColor Cyan
    Start-Process $Url
} else {
    Write-Host "🛑 Setup complete. You can run the container later." -ForegroundColor Green
}
exit
