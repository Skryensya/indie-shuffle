# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IndiesShuffle is an interactive web game built with Phoenix LiveView designed for introverts to cooperate with strangers and solve shared puzzles. It's a multiplayer puzzle game with real-time interactions, user authentication, and admin functionality.

## Development Commands

### Docker Development (Primary)
```bash
# Start application (primary development method)
docker compose up

# Start in background
docker compose up -d

# Rebuild after Dockerfile changes
docker compose up --build

# Run mix commands in container
docker compose exec web mix deps.get
docker compose exec web mix test
docker compose exec web mix format

# Interactive Elixir console
docker compose exec web iex -S mix

# Access container shell
docker compose exec web bash
```

### Local Development (Alternative)
```bash
# Setup project dependencies
mix setup

# Start Phoenix server
mix phx.server

# Start with interactive console
iex -S mix phx.server
```

### Testing and Quality
```bash
# Run all tests
mix test

# Run tests in watch mode
mix dev.test

# Run specific test file
mix test test/path/to/test_file.exs

# Pre-commit quality check (ALWAYS run before committing)
mix precommit

# Quick quality check
mix quality

# CI pipeline
mix ci
```

### Asset Management
```bash
# Setup assets (Tailwind CSS v4 + esbuild)
mix assets.setup

# Build assets for development
mix assets.build

# Build minified assets for production
mix assets.deploy
```

## Architecture Overview

### Core Application Structure
- **IndiesShuffle.Application**: OTP application supervisor
- **IndiesShuffle.Game**: Game logic and state management
  - **GameServer**: GenServer managing individual game sessions
  - **PuzzleEngine**: Core puzzle generation and validation logic
  - **Grouping**: Player matching and group formation
- **IndiesShuffle.BanManager**: Player moderation system
- **IndiesShuffle.Mailer**: Email functionality using Swoosh

### Web Layer (IndiesShuffleWeb)
- **Endpoint**: Phoenix endpoint configuration
- **Router**: Route definitions with live_session authentication
- **Presence**: Real-time user presence tracking
- **Telemetry**: Application monitoring and metrics

### LiveView Components
- **GameLive**: Main game interface with multiple states:
  - `checking_auth.html.heex`: Authentication verification
  - `finding.html.heex`: Matchmaking phase
  - `waiting.html.heex`: Waiting for other players
  - `solving.html.heex`: Active puzzle solving
  - `scoring.html.heex`: Results and scoring
- **LobbyLive**: Game lobby and player matching
- **AdminLive**: Administrative dashboard with login protection
- **UIDemoLive**: UI component showcase

### Game State Flow
1. Players enter via LobbyLive
2. Authentication check (if required)
3. Matchmaking in "finding" state
4. Game session creation via GameServer
5. Real-time puzzle solving with LiveView updates
6. Scoring and results display

## Key Technical Patterns

### Authentication & Authorization
- Admin routes protected by live_session with authentication
- Environment-based admin credentials (ADMIN_USERNAME/ADMIN_PASSWORD)
- Session-based state management for game progression

### Real-time Features
- Phoenix LiveView for real-time UI updates
- Phoenix Presence for player presence tracking
- GameServer GenServer for game state management
- Real-time puzzle collaboration between players

### HTTP Client
- Uses `:req` library for all HTTP requests (avoid httpoison, tesla, httpc)
- Configured in mix.exs dependencies

### Styling & Assets
- Tailwind CSS v4 with new import syntax in app.css
- Heroicons v2.2.0 for SVG icons via `<.icon>` component
- esbuild for JavaScript bundling
- No external vendor scripts - everything bundled through app.js/app.css

## Important Development Notes

### Phoenix LiveView Patterns
- All LiveView templates begin with `<Layouts.app flash={@flash} ...>`
- Use `<.icon name="hero-x-mark" class="w-5 h-5"/>` for all icons
- Forms use `to_form/2` and `<.form for={@form}>` pattern
- Streams used for efficient collection rendering with `phx-update="stream"`

### Game Development Considerations
- Game state persisted in GameServer GenServer processes
- Player actions broadcasted via Phoenix PubSub
- Puzzle validation handled server-side for security
- Ban system for player moderation

### Quality Requirements
- ALWAYS run `mix precommit` before committing changes
- Follow guidelines in AGENTS.md for AI-assisted development
- Use existing LiveView patterns and components
- Maintain Spanish language support (gettext configured)

## Environment Variables

```bash
# Admin Panel Access
ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123
```

See `.env.example` for complete environment configuration.