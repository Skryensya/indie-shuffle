#!/bin/bash

set -e

echo "🏗️  Setting up IndiesShuffle development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}📄 Creating .env file from .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✅ .env file created. You may want to customize it.${NC}"
fi

# Build and start services
echo -e "${BLUE}🐳 Building and starting Docker services...${NC}"
docker compose -f docker-compose.dev.yml up -d --build

# Wait for database to be ready
echo -e "${BLUE}⏳ Waiting for database to be ready...${NC}"
until docker compose -f docker-compose.dev.yml exec db pg_isready -U postgres -d indies_shuffle_dev >/dev/null 2>&1; do
    echo -e "${YELLOW}⏳ Waiting for database...${NC}"
    sleep 2
done

# Install dependencies
echo -e "${BLUE}📦 Installing dependencies...${NC}"
docker compose -f docker-compose.dev.yml exec web mix deps.get

# Setup database
echo -e "${BLUE}🗄️  Setting up database...${NC}"
docker compose -f docker-compose.dev.yml exec web mix ecto.setup

# Setup assets
echo -e "${BLUE}🎨 Setting up assets...${NC}"
docker compose -f docker-compose.dev.yml exec web mix assets.setup

echo -e "${GREEN}🎉 Development environment is ready!${NC}"
echo ""
echo -e "${BLUE}🚀 Access your application:${NC}"
echo -e "   Web: ${GREEN}http://localhost:4000${NC}"
echo -e "   Admin: ${GREEN}http://localhost:4000/admin${NC} (admin/admin123)"
echo -e "   Database: ${GREEN}localhost:5432${NC}"
echo ""
echo -e "${BLUE}📋 Useful commands:${NC}"
echo -e "   ${YELLOW}make help${NC}          - Show all available commands"
echo -e "   ${YELLOW}make logs${NC}          - View application logs"
echo -e "   ${YELLOW}make shell${NC}         - Open shell in web container"
echo -e "   ${YELLOW}make test${NC}          - Run tests"
echo -e "   ${YELLOW}make down${NC}          - Stop all services"
echo ""