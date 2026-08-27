#!/bin/bash
set -e

# Set version tag from git commit
export VERSION=$(git rev-parse --short HEAD)

# Pull latest changes to this deployment repo
git pull

# Build and deploy (Docker will fetch latest zola-site and BackdoorBag)
docker compose build --no-cache
docker compose up -d

echo "Deployment complete! Version: ${VERSION}"
echo "Note: Docker fetched the latest versions of zola-site and BackdoorBag during build"
