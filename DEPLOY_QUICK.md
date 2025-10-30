# 🚀 Deployment Rápido

## 1. Generar SECRET_KEY_BASE (en local)

```bash
docker compose -f docker-compose.dev.yml exec web mix phx.gen.secret
```

Copia el resultado.

## 2. Configurar .env.prod (en servidor)

```bash
# Crea el archivo
cp .env.prod.example .env.prod

# Edita con tus valores
nano .env.prod
```

Configura:
- `PHX_HOST=tu-dominio.com`
- `SECRET_KEY_BASE=el_secreto_que_generaste`

## 3. Verificar red de Traefik

```bash
docker network ls | grep traefik_proxy
```

Si no existe:
```bash
docker network create traefik_proxy
```

## 4. Deploy automático

```bash
./deploy.sh
```

¡Eso es todo! 🎉

Tu app estará en: `https://tu-dominio.com`

---

Para más detalles, ver [DEPLOYMENT.md](./DEPLOYMENT.md)
