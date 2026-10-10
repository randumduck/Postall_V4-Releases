#!/usr/bin/env bash
set -e

echo "🚀 Starting Postall_V4 Pre-flight checks..."

if ! command -v docker &> /dev/null; then
    echo "⚠️ Docker is not installed."
    read -p "Do you want to install Docker now? (y/n) " install_docker
    if [[ "$install_docker" =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "macOS detected. Installing Docker Desktop via Homebrew..."
            if ! command -v brew &> /dev/null; then
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install --cask docker
            echo "✅ Please start Docker Desktop from your Applications folder."
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Linux detected. Fetching official Docker script..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo usermod -aG docker "$USER"
            rm get-docker.sh
            echo "✅ Docker installed. Log out and back in, or run 'sudo systemctl start docker'."
        else
            echo "❌ Unsupported OS. Please install Docker manually."
            exit 1
        fi
    else
        echo "❌ Docker is required. Exiting."
        exit 1
    fi
else
    echo "✅ Docker is already installed."
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start it and try again."
    exit 1
fi

IMAGE_NAME="randumduck69/postall:v4-latest"
CONTAINER_NAME="postall_engine"

echo "📥 Pulling the latest Postall_V4 image..."
docker pull "$IMAGE_NAME"

read -p "✅ Image pulled successfully. Do you want to run Postall_V4 now? (y/n) " run_app
if [[ "$run_app" =~ ^[Yy]$ ]]; then
    echo "⚙️ Starting Postall_V4 with a strict 4 GB memory limit for high-performance offline AI..."
    docker volume create postall_data >/dev/null 2>&1 || true
    
    # Remove existing container if it exists
    if docker ps -a -q -f name="^${CONTAINER_NAME}$" > /dev/null; then
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi

    docker run -d \
        --name "$CONTAINER_NAME" \
        -p 8000:8000 \
        -v postall_data:/app/data \
        --memory="4g" \
        --memory-swap="4g" \
        --log-opt max-size=50m \
        --log-opt max-file=3 \
        --restart unless-stopped \
        "$IMAGE_NAME"
    
    echo "✅ Container '$CONTAINER_NAME' is securely running in the background."
    URL="http://localhost:8000"
    echo "🌐 Opening $URL in your default web browser..."
    
    if command -v xdg-open &> /dev/null; then
        xdg-open "$URL"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open "$URL"
    else
        echo "⚠ Could not detect browser. Please navigate to $URL manually."
    fi
else
    echo "🛑 Setup complete. You can run the container later."
fi
exit 0