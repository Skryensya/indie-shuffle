# IndiesShuffle

Un juego interactivo diseñado para que personas introvertidas cooperen con desconocidos y resuelvan acertijos compartidos — construido con Phoenix.

## 🚀 Inicio Rápido

### Requisitos Previos

* [Docker Desktop](https://docs.docker.com/get-docker/) - Requerido para el entorno de desarrollo

### Puesta en Marcha

1. **Clona el repositorio**
   ```bash
   git clone https://github.com/Skryensya/indie-shuffle.git
   cd indies_shuffle
   ```

2. **Configura las variables de entorno**
   ```bash
   cp .env.example .env
   # Edita .env con tus valores de configuración
   ```

3. **Inicia la aplicación**
   ```bash
   docker compose up
   ```

4. **Accede a la aplicación**
   
   Abre tu navegador y ve a [`http://localhost:4000`](http://localhost:4000)

¡Eso es todo! El contenedor Docker automáticamente:
- Instalará todas las dependencias de Elixir
- Instalará las dependencias de Node.js para los assets
- Compilará los assets (Tailwind CSS + esbuild)
- Iniciará el servidor Phoenix con hot reloading

## �️ Desarrollo con Docker

### Comandos Comunes

```bash
# Iniciar en primer plano (ver logs)
docker compose up

# Iniciar en segundo plano
docker compose up -d

# Reconstruir después de cambios en Dockerfile
docker compose up --build

# Detener la aplicación
docker compose down

# Ver logs en tiempo real
docker compose logs -f web

# Ejecutar comandos mix dentro del contenedor
docker compose exec web mix deps.get
docker compose exec web mix test
docker compose exec web mix format

# Iniciar una consola interactiva de Elixir
docker compose exec web iex -S mix

# Acceder al shell del contenedor
docker compose exec web bash
```

### Trabajar con Dependencias

Cuando agregues nuevas dependencias a `mix.exs`:

```bash
# El contenedor se actualiza automáticamente al reiniciar, o manualmente ejecuta:
docker compose exec web mix deps.get
docker compose exec web mix deps.compile
```

## 💻 Desarrollo Local (Alternativa)

Si prefieres ejecutar la aplicación localmente sin Docker:

### Requisitos
* **Elixir** 1.15+ con Erlang/OTP 24+
* **Node.js** 20+ y npm

### Configuración

```bash
# Instalar dependencias
mix setup

# Iniciar el servidor Phoenix
mix phx.server

# O iniciar con consola interactiva de Elixir
iex -S mix phx.server
```

Visita [`localhost:4000`](http://localhost:4000) en tu navegador.

## 🎯 Flujo de Trabajo de Desarrollo

### Alias de Mix

El proyecto incluye alias útiles de Mix definidos en `mix.exs`:

```bash
# Configuración del proyecto
mix setup              # Instalar todas las dependencias y configurar el proyecto
mix assets.setup       # Instalar Tailwind y esbuild
mix assets.build       # Compilar assets
mix assets.deploy      # Construir assets minificados para producción

# Desarrollo
mix dev.server         # Iniciar servidor Phoenix (alias de mix phx.server)
mix dev.test           # Ejecutar tests en modo watch
mix dev.format         # Formatear código

# Control de calidad
mix precommit          # Ejecutar antes de hacer commit (compilar con warnings, formatear, test)
mix quality            # Chequeo rápido de calidad (formatear + test)
mix ci                 # Pipeline completo de CI
```

### Lista de Verificación Pre-commit

Antes de hacer commit de código, ejecuta:

```bash
mix precommit
```

Esto:
1. Compilará con warnings como errores
2. Eliminará dependencias no utilizadas
3. Formateará todo el código
4. Ejecutará la suite de tests

### Formateo de Código

El proyecto usa el formateador integrado de Elixir:

```bash
# Formatear todos los archivos
mix format

# Verificar si los archivos están formateados (modo CI)
mix format --check-formatted
```

## 🏗️ Estructura del Proyecto

```
indies_shuffle/
├── assets/              # Assets del frontend
│   ├── css/            # Hojas de estilo (Tailwind CSS v4)
│   ├── js/             # JavaScript (esbuild)
│   └── vendor/         # Assets de terceros (Heroicons)
├── config/             # Configuración de la aplicación
│   ├── config.exs      # Configuración base
│   ├── dev.exs         # Configuración de desarrollo
│   ├── prod.exs        # Configuración de producción
│   ├── runtime.exs     # Configuración de runtime
│   └── test.exs        # Configuración del entorno de test
├── lib/
│   ├── indies_shuffle/        # Lógica central de la aplicación
│   └── indies_shuffle_web/    # Capa web (LiveView, controllers, etc)
├── priv/               # Assets estáticos y traducciones gettext
├── test/               # Archivos de test
├── docker-compose.yml  # Orquestación Docker
├── Dockerfile.dev      # Imagen Docker de desarrollo
└── mix.exs            # Configuración del proyecto y dependencias
```

## 📦 Dependencias Principales

### Framework & Core
- **Phoenix** 1.8.1 - Framework web
- **Phoenix LiveView** 1.1.0 - Actualizaciones de UI en tiempo real
- **Bandit** 1.5+ - Servidor HTTP

### Frontend
- **Tailwind CSS** 0.3+ - Framework CSS utility-first (v4)
- **esbuild** 0.10+ - Bundler de JavaScript
- **Heroicons** v2.2.0 - Iconos SVG hermosos y hechos a mano

### HTTP & API
- **Req** 0.5+ - Cliente HTTP para llamadas a APIs externas
- **Joken** 2.6+ - Manejo de tokens JWT

### Herramientas de Desarrollo
- **Phoenix Live Dashboard** 0.8.3+ - Métricas e insights de desarrollo
- **Phoenix Live Reload** 1.2+ - Hot reloading para templates y assets

## 🧪 Testing

```bash
# Ejecutar todos los tests
mix test

# Ejecutar tests en modo watch (auto-reejecutar al cambiar archivos)
mix dev.test

# Ejecutar archivo de test específico
mix test test/indies_shuffle_web/live/some_live_test.exs

# Ejecutar tests con cobertura
mix test --cover
```

En Docker:
```bash
docker compose exec web mix test
```

## 🔐 Variables de Entorno

Variables de entorno clave (ver `.env.example`):

```bash
# Admin Panel
ADMIN_USERNAME=admin            # Usuario administrador
ADMIN_PASSWORD=admin123         # Contraseña administrador
```

## 📝 Guías de Código

Este proyecto sigue las mejores prácticas de Phoenix y Elixir. Puntos clave:

- Usa LiveView para funcionalidades interactivas
- Sigue las guías en `AGENTS.md` para desarrollo asistido por IA
- Usa `<.form>` y `to_form/2` para todo el manejo de formularios
- Aprovecha las clases de Tailwind CSS (sin `@apply`)
- Usa el componente `<.icon>` integrado para Heroicons
- Ejecuta `mix precommit` antes de hacer push de cambios

## 🚢 Despliegue

Para despliegue en producción:

```bash
# Construir assets de producción
mix assets.deploy

# Iniciar en modo producción
MIX_ENV=prod mix phx.server
```

Consulta las [guías de despliegue de Phoenix](https://hexdocs.pm/phoenix/deployment.html) para instrucciones específicas de cada plataforma.

## 📚 Aprende Más

### Phoenix Framework
* [Sitio Oficial](https://www.phoenixframework.org/)
* [Guías](https://hexdocs.pm/phoenix/overview.html)
* [Documentación](https://hexdocs.pm/phoenix)
* [Foro](https://elixirforum.com/c/phoenix-forum)
* [Código Fuente](https://github.com/phoenixframework/phoenix)

### LiveView
* [Documentación de LiveView](https://hexdocs.pm/phoenix_live_view)
* [Ejemplos de LiveView](https://github.com/phoenixframework/phoenix_live_view/tree/master/lib/phoenix_live_view)

### Tailwind CSS
* [Documentación de Tailwind v4](https://tailwindcss.com/docs)
* [Tailwind Play](https://play.tailwindcss.com/)

## 🤝 Contribuir

1. Haz un fork del repositorio
2. Crea una rama de feature (`git checkout -b feature/amazing-feature`)
3. Haz tus cambios
4. Ejecuta `mix precommit` para asegurar la calidad del código
5. Haz commit de tus cambios (`git commit -m 'Add amazing feature'`)
6. Haz push a la rama (`git push origin feature/amazing-feature`)
7. Abre un Pull Request

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - consulta el archivo [LICENSE](LICENSE) para más detalles.
