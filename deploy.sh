#!/bin/bash
set -e

echo "🚀 Iniciando deployment de Indies Shuffle..."

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Verificar que estamos en el directorio correcto
if [ ! -f "mix.exs" ]; then
    echo -e "${RED}Error: No se encontró mix.exs. Asegúrate de estar en el directorio raíz del proyecto.${NC}"
    exit 1
fi

# Verificar que existe .env.prod
if [ ! -f ".env.prod" ]; then
    echo -e "${YELLOW}⚠️  No se encontró .env.prod${NC}"
    echo "Creando desde .env.prod.example..."
    
    if [ -f ".env.prod.example" ]; then
        cp .env.prod.example .env.prod
        echo -e "${YELLOW}Por favor, edita .env.prod con tus valores reales antes de continuar.${NC}"
        echo "Ejecuta: nano .env.prod"
        exit 1
    else
        echo -e "${RED}Error: Tampoco se encontró .env.prod.example${NC}"
        exit 1
    fi
fi

# Verificar que PHX_HOST y SECRET_KEY_BASE estén configurados
source .env.prod
if [ -z "$PHX_HOST" ] || [ "$PHX_HOST" == "tu-dominio.com" ]; then
    echo -e "${RED}Error: PHX_HOST no está configurado en .env.prod${NC}"
    exit 1
fi

if [ -z "$SECRET_KEY_BASE" ] || [ "$SECRET_KEY_BASE" == "REEMPLAZAR_POR_REAL" ]; then
    echo -e "${RED}Error: SECRET_KEY_BASE no está configurado en .env.prod${NC}"
    echo "Genera uno con: docker compose -f docker-compose.dev.yml exec web mix phx.gen.secret"
    exit 1
fi

echo -e "${GREEN}✓${NC} Configuración validada"

# Pull últimos cambios (si es un repo git)
if [ -d ".git" ]; then
    echo "📥 Pulling latest changes..."
    git pull
fi

# Build de la imagen
echo "🏗️  Building Docker image..."
docker compose -f docker-compose.prod.yml build

# Detener contenedor actual (si existe)
echo "🛑 Stopping current container..."
docker compose -f docker-compose.prod.yml down

# Levantar el nuevo contenedor
echo "🚀 Starting new container..."
docker compose -f docker-compose.prod.yml up -d

# Esperar a que el contenedor esté listo
echo "⏳ Waiting for container to be ready..."
sleep 5

# Ejecutar migraciones
echo "📊 Running migrations..."
docker compose -f docker-compose.prod.yml exec -T web bin/indies_shuffle eval "IndiesShuffle.Release.migrate"

# Verificar que está corriendo
echo "✅ Checking health..."
sleep 3
docker compose -f docker-compose.prod.yml ps

echo ""
echo -e "${GREEN}✨ Deployment completado!${NC}"
echo ""
echo "🌐 Tu aplicación debería estar disponible en: https://$PHX_HOST"
echo ""
echo "📋 Comandos útiles:"
echo "  Ver logs:      docker compose -f docker-compose.prod.yml logs -f"
echo "  Reiniciar:     docker compose -f docker-compose.prod.yml restart"
echo "  Detener:       docker compose -f docker-compose.prod.yml down"
echo "  Consola IEx:   docker compose -f docker-compose.prod.yml exec web bin/indies_shuffle remote"
