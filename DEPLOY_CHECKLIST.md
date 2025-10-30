# ✅ Checklist Pre-Deployment

Antes de deployear en producción, verifica:

## Servidor
- [ ] Docker instalado (`docker --version`)
- [ ] Docker Compose instalado (`docker compose version`)
- [ ] Traefik corriendo (`docker ps | grep traefik`)
- [ ] Red traefik_proxy creada (`docker network ls | grep traefik_proxy`)
- [ ] Dominio apuntando al servidor (DNS configurado)
- [ ] Puertos 80 y 443 abiertos en firewall

## Configuración
- [ ] Archivo `.env.prod` creado en el servidor
- [ ] `PHX_HOST` configurado con tu dominio real
- [ ] `SECRET_KEY_BASE` generado y configurado (64+ caracteres)
- [ ] `SECRET_KEY_BASE` único (no usar el de ejemplo)
- [ ] Variables de entorno verificadas

## Código
- [ ] Código subido al servidor (git clone o rsync)
- [ ] En el directorio correcto del proyecto
- [ ] Archivo `docker-compose.prod.yml` presente
- [ ] Archivo `Dockerfile.prod` presente

## Traefik
- [ ] Traefik configurado con Let's Encrypt
- [ ] Cert resolver configurado (normalmente "le")
- [ ] Entrypoint `websecure` configurado en Traefik

## Pruebas antes de deployment
- [ ] App funciona en desarrollo local
- [ ] Assets compilan sin errores (`mix assets.build`)
- [ ] Tests pasan (`mix test`)
- [ ] No hay warnings críticos

## Post-Deployment
- [ ] Contenedor levantado (`docker ps`)
- [ ] Logs sin errores (`docker compose -f docker-compose.prod.yml logs`)
- [ ] Sitio accesible en `https://tu-dominio.com`
- [ ] WebSockets funcionan (LiveView)
- [ ] Certificado SSL válido
- [ ] Base de datos creada y migrada

## Monitoreo
- [ ] Healthcheck funcionando
- [ ] Logs configurados
- [ ] Backup de DB configurado (opcional)

---

## Comando para generar SECRET_KEY_BASE

```bash
docker compose -f docker-compose.dev.yml exec web mix phx.gen.secret
```

## Verificar configuración de Traefik

```bash
# Ver configuración de Traefik
docker inspect traefik

# Ver redes
docker network inspect traefik_proxy

# Ver logs de Traefik
docker logs traefik -f
```

## En caso de problemas

1. Ver logs del contenedor:
   ```bash
   docker compose -f docker-compose.prod.yml logs -f web
   ```

2. Verificar que Traefik ve el servicio:
   ```bash
   docker compose -f docker-compose.prod.yml config
   ```

3. Verificar conectividad:
   ```bash
   docker compose -f docker-compose.prod.yml exec web wget -qO- http://localhost:4000/
   ```

4. Ver estado de salud:
   ```bash
   docker inspect --format='{{json .State.Health}}' indies_shuffle-web-1 | jq
   ```
