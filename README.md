# IndiesShuffle

A modern web application built with Phoenix LiveView, featuring a Docker-based development environment for streamlined setup and deployment.

## 🚀 Quick Start

### Prerequisites

* [Docker Desktop](https://docs.docker.com/get-docker/) - Required for containerized development
* [Docker Compose](https://docs.docker.com/compose/install/) - Usually included with Docker Desktop

### Getting Started

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd indies_shuffle
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration values
   ```

3. **Start the application**
   ```bash
   docker compose up
   ```

4. **Access the application**
   
   Open your browser and navigate to [`http://localhost:4000`](http://localhost:4000)

That's it! The Docker container will automatically:
- Install all Elixir dependencies
- Install Node.js dependencies for assets
- Compile assets (Tailwind CSS + esbuild)
- Start the Phoenix server with hot reloading

## 🐳 Docker Development

### Container Architecture

The project uses a single-service Docker setup:
- **Base Image:** `elixir:1.15-slim`
- **System Dependencies:** build-essential, git, inotify-tools, Node.js 20, watchman
- **Volumes:** Source code, dependencies, and build artifacts are persisted
- **Hot Reloading:** Enabled via file system watchers

### Common Docker Commands

```bash
# Start in foreground (see logs)
docker compose up

# Start in background
docker compose up -d

# Rebuild after Dockerfile changes
docker compose up --build

# Stop the application
docker compose down

# View logs
docker compose logs -f web

# Run mix commands inside container
docker compose exec web mix deps.get
docker compose exec web mix test
docker compose exec web mix format

# Start an interactive Elixir shell
docker compose exec web iex -S mix

# Access container shell
docker compose exec web bash
```

### Working with Dependencies

When you add new dependencies to `mix.exs`:

```bash
# The container auto-updates on restart, or manually run:
docker compose exec web mix deps.get
docker compose exec web mix deps.compile
```

## 💻 Local Development (Alternative)

If you prefer to run the application locally without Docker:

### Prerequisites
* **Elixir** 1.15+ with Erlang/OTP 24+
* **Node.js** 20+ and npm
* **PostgreSQL** 14+ (if using a database)

### Setup

```bash
# Install dependencies
mix setup

# Start Phoenix server
mix phx.server

# Or start with interactive Elixir shell
iex -S mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## 🛠️ Development Workflow

### Mix Aliases

The project includes helpful Mix aliases defined in `mix.exs`:

```bash
# Project setup
mix setup              # Install all dependencies and setup project
mix assets.setup       # Install Tailwind and esbuild
mix assets.build       # Compile assets
mix assets.deploy      # Build minified assets for production

# Development
mix dev.server         # Start Phoenix server (alias for mix phx.server)
mix dev.test           # Run tests in watch mode
mix dev.format         # Format code

# Quality checks
mix precommit          # Run before committing (compile with warnings, format, test)
mix quality            # Quick quality check (format + test)
mix ci                 # Full CI pipeline (used in continuous integration)
```

### Pre-commit Checklist

Before committing code, run:

```bash
mix precommit
```

This will:
1. Compile with warnings as errors
2. Remove unused dependencies
3. Format all code
4. Run the test suite

### Code Formatting

The project uses Elixir's built-in formatter:

```bash
# Format all files
mix format

# Check if files are formatted (CI mode)
mix format --check-formatted
```

## 🏗️ Project Structure

```
indies_shuffle/
├── assets/              # Frontend assets
│   ├── css/            # Stylesheets (Tailwind CSS v4)
│   ├── js/             # JavaScript (esbuild)
│   └── vendor/         # Third-party assets (Heroicons)
├── config/             # Application configuration
│   ├── config.exs      # Base configuration
│   ├── dev.exs         # Development config
│   ├── prod.exs        # Production config
│   ├── runtime.exs     # Runtime configuration
│   └── test.exs        # Test environment config
├── lib/
│   ├── indies_shuffle/        # Core application logic
│   └── indies_shuffle_web/    # Web layer (LiveView, controllers, etc)
├── priv/               # Static assets and gettext translations
├── test/               # Test files
├── docker-compose.yml  # Docker orchestration
├── Dockerfile.dev      # Development Docker image
└── mix.exs            # Project configuration and dependencies
```

## 📦 Key Dependencies

### Framework & Core
- **Phoenix** 1.8.1 - Web framework
- **Phoenix LiveView** 1.1.0 - Real-time UI updates
- **Bandit** 1.5+ - HTTP server

### Frontend
- **Tailwind CSS** 0.3+ - Utility-first CSS framework (v4)
- **esbuild** 0.10+ - JavaScript bundler
- **Heroicons** v2.2.0 - Beautiful hand-crafted SVG icons

### HTTP & API
- **Req** 0.5+ - HTTP client for external API calls
- **Joken** 2.6+ - JWT token handling

### Development Tools
- **Phoenix Live Dashboard** 0.8.3+ - Development metrics and insights
- **Phoenix Live Reload** 1.2+ - Hot reloading for templates and assets

## 🧪 Testing

```bash
# Run all tests
mix test

# Run tests in watch mode (auto-rerun on file changes)
mix dev.test

# Run specific test file
mix test test/indies_shuffle_web/live/some_live_test.exs

# Run tests with coverage
mix test --cover
```

In Docker:
```bash
docker compose exec web mix test
```

## 🔐 Environment Variables

Key environment variables (see `.env.example`):

```bash
# Phoenix Configuration
PHX_HOST=localhost              # Host for the Phoenix server
PHX_PORT=4000                   # Port for the Phoenix server
SECRET_KEY_BASE=<secret>        # Secret key for sessions/cookies

# Environment
MIX_ENV=dev                     # Elixir environment (dev/test/prod)

# Admin Panel (if applicable)
ADMIN_USERNAME=<username>       # Admin credentials
ADMIN_PASSWORD=<password>       # Admin credentials
```

## 📝 Code Guidelines

This project follows Phoenix and Elixir best practices. Key points:

- Use LiveView for interactive features
- Follow the guidelines in `AGENTS.md` for AI-assisted development
- Use `<.form>` and `to_form/2` for all form handling
- Leverage Tailwind CSS classes (no `@apply`)
- Use the built-in `<.icon>` component for Heroicons
- Run `mix precommit` before pushing changes

## 🚢 Deployment

For production deployment:

```bash
# Build production assets
mix assets.deploy

# Start in production mode
MIX_ENV=prod mix phx.server
```

Consult the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html) for platform-specific instructions.

## 📚 Learn More

### Phoenix Framework
* [Official Website](https://www.phoenixframework.org/)
* [Guides](https://hexdocs.pm/phoenix/overview.html)
* [Documentation](https://hexdocs.pm/phoenix)
* [Forum](https://elixirforum.com/c/phoenix-forum)
* [Source Code](https://github.com/phoenixframework/phoenix)

### LiveView
* [LiveView Documentation](https://hexdocs.pm/phoenix_live_view)
* [LiveView Examples](https://github.com/phoenixframework/phoenix_live_view/tree/master/lib/phoenix_live_view)

### Tailwind CSS
* [Tailwind v4 Documentation](https://tailwindcss.com/docs)
* [Tailwind Play](https://play.tailwindcss.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `mix precommit` to ensure code quality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

[Add your license here]
