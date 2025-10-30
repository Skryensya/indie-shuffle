# Guía de Deployment - Indies Shuffle

## Pre-requisitos en el servidor

1. **Docker y Docker Compose** instalados
2. **Traefik** corriendo en la red `traefik_proxy`
3. **Dominio** apuntando a tu servidor

## Pasos para deployear

### 1. Generar SECRET_KEY_BASE

En tu máquina local, ejecuta:

```bash
docker compose -f docker-compose.dev.yml exec web mix phx.gen.secret
```

Copia el resultado (es un string largo).

### 2. Crear archivo .env.prod en el servidor

En tu servidor, crea el archivo `.env.prod` con este contenido:

```bash
# Phoenix Configuration
PHX_HOST=tu-dominio.com
SECRET_KEY_BASE=pega_aqui_el_secreto_generado
DATABASE_PATH=/app/db/indies_shuffle.db

# URL Configuration
URL_HOST=tu-dominio.com
URL_PORT=443
URL_SCHEME=https
PORT=4000
PHX_SERVER=true
MIX_ENV=prod
```

**IMPORTANTE**: Reemplaza `tu-dominio.com` con tu dominio real.

### 3. Verificar configuración de Traefik

Asegúrate de que tu red de Traefik existe:

```bash
docker network ls | grep traefik_proxy
```

Si no existe, créala:

```bash
docker network create traefik_proxy
```

### 4. Subir código al servidor

Opción A - Git (recomendado):
```bash
# En el servidor
git clone https://github.com/Skryensya/indie-shuffle.git
cd indie-shuffle
```

Opción B - rsync:
```bash
# En tu máquina local
rsync -avz --exclude 'node_modules' --exclude '_build' --exclude 'deps' \
  ./ usuario@servidor:/ruta/al/proyecto/
```

### 5. Build y deploy

En el servidor, dentro del directorio del proyecto:

```bash
# Build de la imagen
docker compose -f docker-compose.prod.yml build

# Levantar el servicio
docker compose -f docker-compose.prod.yml up -d

# Ver logs
docker compose -f docker-compose.prod.yml logs -f
```

### 6. Crear la base de datos

```bash
# Ejecutar migraciones
docker compose -f docker-compose.prod.yml exec web bin/indies_shuffle eval "IndiesShuffle.Release.migrate"
```

### 7. Verificar que funciona

```bash
# Ver logs
docker compose -f docker-compose.prod.yml logs -f web

# Verificar que el contenedor está corriendo
docker compose -f docker-compose.prod.yml ps

# Probar el healthcheck
docker compose -f docker-compose.prod.yml exec web wget -qO- http://localhost:4000/
```

Luego visita `https://tu-dominio.com` en tu navegador.

## Comandos útiles

### Ver logs en tiempo real
```bash
docker compose -f docker-compose.prod.yml logs -f web
```

### Reiniciar el servicio
```bash
docker compose -f docker-compose.prod.yml restart web
```

### Detener todo
```bash
docker compose -f docker-compose.prod.yml down
```

### Actualizar después de cambios
```bash
# Pull últimos cambios
git pull

# Rebuild y restart
docker compose -f docker-compose.prod.yml build
docker compose -f docker-compose.prod.yml up -d

# Ejecutar migraciones si hay
docker compose -f docker-compose.prod.yml exec web bin/indies_shuffle eval "IndiesShuffle.Release.migrate"
```

### Acceder a consola IEx
```bash
docker compose -f docker-compose.prod.yml exec web bin/indies_shuffle remote
```

### Backup de la base de datos
```bash
docker compose -f docker-compose.prod.yml exec web cp /app/db/indies_shuffle.db /app/db/backup_$(date +%Y%m%d_%H%M%S).db
```

## Troubleshooting

### El sitio no carga
1. Verifica logs: `docker compose -f docker-compose.prod.yml logs -f`
2. Verifica que Traefik puede acceder: `docker network inspect traefik_proxy`
3. Verifica el SECRET_KEY_BASE está configurado

### Error de base de datos
1. Verifica permisos del directorio: `ls -la` en el volumen
2. Ejecuta migraciones: `docker compose -f docker-compose.prod.yml exec web bin/indies_shuffle eval "IndiesShuffle.Release.migrate"`

### Puerto 4000 ya en uso
Cambia el puerto en docker-compose.prod.yml y en .env.prod

## Configuración de Traefik

Tu `docker-compose.prod.yml` ya tiene las labels correctas:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.indies.rule=Host(`${PHX_HOST}`)"
  - "traefik.http.routers.indies.entrypoints=websecure"
  - "traefik.http.routers.indies.tls.certresolver=le"
  - "traefik.http.services.indies.loadbalancer.server.port=4000"
```

Solo asegúrate de que `PHX_HOST` esté correcto en tu `.env.prod`.

## Monitoreo

### Healthcheck
El contenedor tiene un healthcheck incorporado que se ejecuta cada 30 segundos.

```bash
docker inspect --format='{{json .State.Health}}' indies_shuffle-web-1 | jq
```

## Seguridad

- ✅ SECRET_KEY_BASE único y seguro
- ✅ HTTPS con Let's Encrypt vía Traefik
- ✅ No exponer puertos directamente (solo a través de Traefik)
- ✅ Usuario no-root en el contenedor
- ⚠️ Considera añadir rate limiting en Traefik para la API

## Notas importantes

- La base de datos SQLite está en un volumen Docker persistente
- Los assets se precompilan durante el build
- El contenedor corre como usuario `app` (no root)
- WebSockets están habilitados para LiveView
