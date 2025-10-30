defmodule IndiesShuffleWeb.LobbyLive do
  use IndiesShuffleWeb, :live_view
  alias IndiesShuffleWeb.Presence
  alias Phoenix.PubSub

  # Embed templates from the lobby_live/ directory
  embed_templates "lobby_live/*"

  @impl true
  def render(assigns), do: index(assigns)

  @topic "lobby:presence"
  @token_ttl 60 * 60 * 6  # 6 horas en segundos

  # Generar JWT con nombre e indie_id
  defp generate_jwt(name, indie_id) do
    claims = %{
      "name" => name,
      "indie_id" => indie_id,
      "token_type" => "indie_user",
      "exp" => Joken.current_time() + @token_ttl,
      "iat" => Joken.current_time()
    }

    signer = Joken.Signer.create("HS256", "indie_shuffle_jwt_secret_key_2025_super_secure")

    case Joken.encode_and_sign(claims, signer) do
      {:ok, token, _claims} -> token
      {:error, _reason} -> nil
    end
  end

  # Validar y extraer datos del JWT
  defp validate_jwt(token) when is_binary(token) do
    try do
      signer = Joken.Signer.create("HS256", "indie_shuffle_jwt_secret_key_2025_super_secure")
      case Joken.verify_and_validate(%{}, token, signer) do
        {:ok, claims} ->
          case claims do
            %{"name" => name, "indie_id" => indie_id, "token_type" => "indie_user"}
              when is_binary(name) and is_binary(indie_id) ->
              {:ok, %{name: name, indie_id: indie_id}}
            _ ->
              {:error, :invalid_claims}
          end
        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        IO.puts("💥 Error en validate_jwt: #{inspect(error)}")
        {:error, :jwt_error}
    end
  end
  defp validate_jwt(_), do: {:error, :invalid_token}

  @impl true
  def mount(_params, _session, socket) do
    # Generar datos iniciales
    token = generate_token()
    # El indie_id ahora se generará o recuperará desde el cliente

    socket =
      socket
      |> assign(:token, token)
      |> assign(:indie_id, nil)  # Se asignará desde el cliente
      |> assign(:name, nil)
      |> assign(:joined, false)
      |> assign(:editing, false)
      |> assign(:players, [])
      |> assign(:game_state, :waiting)
      |> assign(:players_needed, 0)
      |> assign(:can_start_game, false)
      |> assign(:checking_auth, true)  # Nuevo estado para mostrar loading
      |> assign(:show_logout_modal, false)  # Control del modal
      |> assign(:game_active, false)
      |> assign(:my_group, nil)
      |> assign(:my_question, nil)
      |> assign(:current_game_id, nil)
      |> assign(:game_phase, :waiting)
      |> assign(:current_game_state, nil)
      |> assign(:player_info, nil)
      |> assign(:game_mode, "groups")
      |> assign(:finding_team_remaining, 0)

    if connected?(socket) do
      PubSub.subscribe(IndiesShuffle.PubSub, @topic)
      PubSub.subscribe(IndiesShuffle.PubSub, "game:broadcast")  # Subscribe to game events
      # Timeout de seguridad para el loading
      Process.send_after(self(), :auth_timeout, 1000)
    end

    updated_socket =
      socket
      |> assign(:players, list_players())
      |> update_game_state()
      |> check_and_join_active_game()

    {:ok, updated_socket}
  end

  # Inicialización desde localStorage/cookies
  @impl true
  def handle_event("init_token", %{"token" => _token, "name" => name, "indie_id" => indie_id}, socket) do
    # Si hay datos en localStorage pero no en el socket, sincronizar
    if name && String.trim(name) != "" && (!socket.assigns.name || socket.assigns.name == "") do
      cleaned_name = String.trim(name)

      # Usar indie_id si viene del localStorage, sino el que ya tenemos
      final_indie_id = if indie_id && indie_id != "", do: indie_id, else: socket.assigns.indie_id

      # Guardar en cookie vía JavaScript
      cookie_data = %{
        name: cleaned_name,
        token: socket.assigns.token,
        indie_id: final_indie_id
      }

      updated_socket =
        socket
        |> assign(:name, cleaned_name)
        |> assign(:indie_id, final_indie_id)
        |> assign(:joined, true)
        |> assign(:checking_auth, false)
        |> track_user_presence()
        |> assign(:players, list_players())
        |> update_game_state()
        |> push_event("save-to-cookie", cookie_data)

      {:noreply, updated_socket}
    else
      {:noreply, socket}
    end
  end

  # Guardar o cambiar nombre
  @impl true
  def handle_event("set_name", %{"name" => name, "token" => _token}, socket) do
    IO.puts("📝 set_name llamado - Nombre: '#{name}', Usuario actual: '#{socket.assigns.name}', Editing: #{socket.assigns.editing}, Joined: #{socket.assigns.joined}")

    cleaned =
      name
      |> String.trim()
      |> String.slice(0, 40)
      |> case do
        "" -> nil
        val -> val
      end

    IO.puts("🧹 Nombre limpio: '#{inspect(cleaned)}'")

    # No permitir nombres vacíos
    if cleaned do
      # Verificar que indie_id exista
      if !socket.assigns.indie_id do
        IO.puts("⚠️ indie_id no inicializado, esperando...")
        {:noreply,
         socket
         |> put_flash(:error, "Error de inicialización. Por favor, recarga la página.")}
      else
        # Check if user is banned before allowing them to set name/join
        if IndiesShuffle.BanManager.is_banned?(socket.assigns.indie_id) do
          IO.puts("🚫 Usuario baneado intentando unirse: #{cleaned} (#{socket.assigns.indie_id})")
          {:noreply,
           socket
           |> assign(:joined, false)
           |> assign(:editing, false)
           |> put_flash(:error, "Tu cuenta ha sido suspendida. Contacta al administrador.")}
        else
          # Generar JWT con nombre e indie_id
          jwt_token = generate_jwt(cleaned, socket.assigns.indie_id)

      if jwt_token do
        IO.puts("💾 Generando JWT para: #{cleaned} (#{socket.assigns.indie_id})")
        IO.puts("🔐 JWT: #{String.slice(jwt_token, 0, 50)}...")

        # Si el usuario ya estaba unido, primero limpiar su presencia anterior
        if socket.assigns.joined and socket.assigns.indie_id do
          IO.puts("🧹 Limpiando presencia anterior para cambio de nombre")
          Presence.untrack(self(), @topic, socket.assigns.indie_id)
        end

        updated_socket =
          socket
          |> assign(:name, cleaned)
          |> assign(:joined, true)
          |> assign(:editing, false)
          |> assign(:checking_auth, false)
          |> track_user_presence()
          |> assign(:players, list_players())
          |> update_game_state()
          |> check_and_join_active_game()
          |> push_event("save-jwt-cookie", %{jwt: jwt_token})

        # Notificar al navegador para actualizar localStorage
        Process.send_after(self(), {:push_local_update, cleaned, socket.assigns.indie_id}, 100)

        IO.puts("✅ Nombre actualizado exitosamente a: #{cleaned}")
        {:noreply, updated_socket}
      else
        IO.puts("❌ Error generando JWT")
        {:noreply, socket}
      end
        end
      end
    else
      # Nombre vacío - mantener estado sin permitir entrada
      IO.puts("⚠️ Nombre vacío, manteniendo estado")
      {:noreply,
       socket
       |> assign(:joined, false)
       |> assign(:editing, false)}
    end
  end

  @impl true
  def handle_event("edit_name", _, socket) do
    # Don't allow name editing during active games
    if socket.assigns.game_active do
      IO.puts("🚫 Usuario #{socket.assigns.name} intentó editar nombre durante juego activo")
      {:noreply,
       socket
       |> put_flash(:error, "No puedes cambiar tu nombre durante un juego activo.")}
    else
      IO.puts("🖊️ Usuario #{socket.assigns.name} (#{socket.assigns.indie_id}) quiere editar su nombre")
      {:noreply, assign(socket, :editing, true)}
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket) do
    {:noreply, assign(socket, :editing, false)}
  end

  @impl true
  def handle_event("show_logout_modal", _, socket) do
    {:noreply, assign(socket, :show_logout_modal, true)}
  end

  @impl true
  def handle_event("hide_logout_modal", _, socket) do
    {:noreply, assign(socket, :show_logout_modal, false)}
  end

  # Handle return to lobby from ended game ONLY
  @impl true
  def handle_event("return_to_lobby", _params, socket) do
    # Only allow returning to lobby if game has ended
    if socket.assigns.game_phase == :ended do
      {:noreply,
       socket
       |> assign(:game_active, false)
       |> assign(:current_game_id, nil)
       |> assign(:current_game_state, nil)
       |> assign(:player_info, nil)
       |> assign(:my_group, nil)
       |> assign(:my_question, nil)
       |> assign(:game_phase, :waiting)
       |> push_event("clear-game-state", %{})}
    else
      # During active game, users cannot return to lobby
      {:noreply,
       socket
       |> put_flash(:error, "No puedes volver al lobby durante un juego activo. Solo puedes cerrar sesión.")}
    end
  end

  # Validar JWT desde cookie
  @impl true
  def handle_event("validate_jwt", %{"jwt" => jwt_token}, socket) do
    try do
      IO.puts("🔐 Validando JWT: #{String.slice(jwt_token, 0, 20)}...")
      IO.puts("🔍 JWT completo: #{jwt_token}")

      case validate_jwt(jwt_token) do
        {:ok, %{name: name, indie_id: indie_id}} ->
          # Check if user is banned
          if IndiesShuffle.BanManager.is_banned?(indie_id) do
            IO.puts("🚫 Usuario baneado intentando conectar: #{name} (#{indie_id})")
            {:noreply,
             socket
             |> assign(:checking_auth, false)
             |> put_flash(:error, "Tu cuenta ha sido suspendida. Contacta al administrador.")}
          else
            IO.puts("✅ JWT válido - auto-login: #{name} (#{indie_id})")

            # Generar token para esta sesión
            session_token = generate_token()
            IO.puts("🎫 Token de sesión generado: #{session_token}")

            updated_socket =
              socket
              |> assign(:name, name)
              |> assign(:token, session_token)
              |> assign(:indie_id, indie_id)
              |> assign(:joined, true)
              |> assign(:checking_auth, false)
              |> track_user_presence()
              |> assign(:players, list_players())
              |> update_game_state()
              |> check_and_join_active_game()

            {:noreply, updated_socket}
          end

        {:error, reason} ->
          IO.puts("❌ JWT inválido o expirado: #{reason}")
          IO.puts("🔍 Detalle del error: #{inspect(reason)}")
          {:noreply, assign(socket, :checking_auth, false)}
      end
    rescue
      error ->
        IO.puts("💥 Error en handle_event validate_jwt: #{inspect(error)}")
        {:noreply, assign(socket, :checking_auth, false)}
    end
  end

  # Evento para cuando no hay datos de autenticación (usuario nuevo)
  @impl true
  def handle_event("no_auth_data", _, socket) do
    {:noreply, assign(socket, :checking_auth, false)}
  end

  # Evento para inicializar o recuperar indie_id persistente
  @impl true
  def handle_event("init_indie_id", %{"indie_id" => indie_id}, socket) do
    IO.puts("🆔 Inicializando indie_id: #{indie_id}")
    {:noreply, assign(socket, :indie_id, indie_id)}
  end

  @impl true
  def handle_event("start_game", _, socket) do
    # Users cannot start games - only admin can
    # Also prevent during active games
    if socket.assigns.game_active do
      {:noreply,
       socket
       |> put_flash(:error, "Ya hay un juego en progreso")}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Solo el administrador puede iniciar el juego")}
    end
  end

  @impl true
  def handle_event("confirm_logout", _, socket) do
    IO.puts("🚪 Usuario cerrando sesión: #{socket.assigns.name || "Anónimo"}")

    # Si el usuario está en un juego activo, notificar al GameServer
    if socket.assigns.game_active and socket.assigns.current_game_id do
      try do
        IndiesShuffle.Game.GameServer.player_disconnected(
          socket.assigns.current_game_id,
          socket.assigns.indie_id
        )
        IO.puts("✅ Usuario #{socket.assigns.indie_id} desconectado del juego #{socket.assigns.current_game_id}")
      rescue
        error ->
          IO.puts("⚠️ Error al desconectar del juego: #{inspect(error)}")
      end
    end

    # Limpiar presence si el usuario estaba conectado
    if socket.assigns.joined and socket.assigns.indie_id do
      Presence.untrack(self(), @topic, socket.assigns.indie_id)
    end

    updated_socket =
      socket
      |> reset_session_state()
      |> assign(:show_logout_modal, false)
      |> assign(:game_active, false)
      |> assign(:current_game_id, nil)
      |> assign(:current_game_state, nil)
      |> assign(:player_info, nil)
      |> push_event("clear-all-auth", %{})
      |> put_flash(:info, "Sesión cerrada correctamente")

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    updated_socket =
      socket
      |> assign(:players, list_players())
      |> update_game_state()

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info({:push_local_update, name, indie_id}, socket) do
    {:noreply, push_event(socket, "phx:update-local", %{name: name, indie_id: indie_id})}
  end

  @impl true
  def handle_info(:auth_timeout, socket) do
    # Timeout de seguridad - desactivar loading si aún está activo
    if socket.assigns.checking_auth do
      IO.puts("⏰ Timeout de autenticación - mostrando formulario")
      {:noreply, assign(socket, :checking_auth, false)}
    else
      {:noreply, socket}
    end
  end

  # Handle admin disconnect
  @impl true
  def handle_info({:admin_disconnect, message}, socket) do
    IO.puts("🚨 Admin disconnect: #{message}")

    # Clean up presence
    if socket.assigns.joined and socket.assigns.indie_id do
      Presence.untrack(self(), @topic, socket.assigns.indie_id)
    end

    {:noreply,
     socket
     |> reset_session_state()
     |> put_flash(:error, message)
     |> push_event("clear-all-auth", %{})}
  end

  # Handle admin ban
  @impl true
  def handle_info({:admin_ban, message}, socket) do
    IO.puts("🚫 Admin ban: #{message}")

    # Clean up presence
    if socket.assigns.joined and socket.assigns.indie_id do
      Presence.untrack(self(), @topic, socket.assigns.indie_id)
    end

    {:noreply,
     socket
     |> reset_session_state()
     |> put_flash(:error, message)
     |> push_event("clear-all-auth", %{})}
  end

  # Handle game started with redirect (from admin panel or question change)
  @impl true
  def handle_info({:game_event, {:game_started_redirect, game_id, mode, groups}}, socket) do
    IO.puts("🎮 Game event! Mode: #{mode}, Game ID: #{game_id}")

    # Find this player's group and question
    my_indie_id = socket.assigns.indie_id

    {my_group, my_question} = Enum.find_value(groups, {nil, nil}, fn group ->
      member = Enum.find(group.members, &(&1.indie_id == my_indie_id))
      if member, do: {group, group.question}, else: nil
    end)

    if my_group do
      IO.puts("🎮 Player #{my_indie_id} assigned to group #{my_group.id} with question: #{my_question}")

      # Only subscribe if not already subscribed (first time joining)
      if !socket.assigns.game_active do
        PubSub.subscribe(IndiesShuffle.PubSub, "game:" <> game_id)
        # Start timer for updating game state
        Process.send_after(self(), :update_game_state, 1000)
      end

      # Get initial game state to get correct timer value and phase
      {game_state, player_info} = try do
        full_game_state = IndiesShuffle.Game.GameServer.get_state(game_id)
        player_info = %{
          player_id: my_indie_id,
          group_id: my_group.id,
          group_emoji: my_group.emoji,
          group_members: my_group.members,
          leader_id: my_group.leader_id
        }
        {full_game_state, player_info}
      catch
        :exit, _ ->
          # Fallback game state
          fallback_state = %{
            id: game_id,
            mode: mode,
            phase: :finding_team,
            groups: groups,
            finding_team_remaining: 31_000
          }
          player_info = %{
            player_id: my_indie_id,
            group_id: my_group.id,
            group_emoji: my_group.emoji,
            group_members: my_group.members,
            leader_id: my_group.leader_id
          }
          {fallback_state, player_info}
      end

      {:noreply,
       socket
       |> assign(:game_active, true)
       |> assign(:current_game_id, game_id)
       |> assign(:game_mode, mode)
       |> assign(:current_game_state, game_state)
       |> assign(:player_info, player_info)
       |> assign(:my_group, my_group)
       |> assign(:my_question, my_question)
       |> assign(:game_phase, game_state.phase)
       |> assign(:finding_team_remaining, game_state.finding_team_remaining || 0)
       |> push_event("save-game-state", %{
         game_id: game_id,
         group_id: my_group.id,
         game_phase: game_state.phase,
         mode: mode
       })}
    else
      IO.puts("⚠️ Player #{my_indie_id} not found in any group")
      {:noreply, socket}
    end
  end

  # Handle game started (legacy, kept for compatibility)
  @impl true
  def handle_info({:game_event, {:game_started, mode, groups}}, socket) do
    IO.puts("🎮 Game started! Mode: #{mode}")

    # Find this player's group and question
    my_indie_id = socket.assigns.indie_id

    {my_group, my_question} = Enum.find_value(groups, {nil, nil}, fn group ->
      member = Enum.find(group.members, &(&1.indie_id == my_indie_id))
      if member, do: {group, group.question}, else: nil
    end)

    if my_group do
      # Try to get full game state if we have game_id
      socket = if socket.assigns.current_game_id do
        try do
          game_state = IndiesShuffle.Game.GameServer.get_state(socket.assigns.current_game_id)

          player_info = %{
            player_id: my_indie_id,
            group_id: my_group.id,
            group_emoji: my_group.emoji,
            group_members: my_group.members,
            leader_id: my_group.leader_id
          }

          socket
          |> assign(:current_game_state, game_state)
          |> assign(:player_info, player_info)
        catch
          :exit, _ -> socket
        end
      else
        socket
      end

      {:noreply,
       socket
       |> assign(:game_active, true)
       |> assign(:game_mode, mode)
       |> assign(:my_group, my_group)
       |> assign(:my_question, my_question)
       |> assign(:game_phase, :finding_team)}
    else
      {:noreply, socket}
    end
  end

  # Handle game ended
  @impl true
  def handle_info({:game_event, {:game_ended}}, socket) do
    IO.puts("🎮 Game ended!")

    {:noreply,
     socket
     |> assign(:game_phase, :ended)
     |> push_event("clear-game-state", %{})
     |> put_flash(:info, "El juego ha terminado")}
  end

  # Handle phase change from game events
  @impl true
  def handle_info({:game_event, {:phase_change, new_phase}}, socket) do
    IO.puts("🎮 Phase changed to: #{new_phase}")
    IO.puts("📊 Current assigns: game_active=#{socket.assigns.game_active}, game_phase=#{socket.assigns.game_phase}")

    updated_socket = assign(socket, :game_phase, new_phase)
    IO.puts("📊 Updated game_phase to: #{updated_socket.assigns.game_phase}")

    {:noreply, updated_socket}
  end

  # Handle phase change (legacy - might be used elsewhere)
  @impl true
  def handle_info({:phase_change, new_phase}, socket) do
    IO.puts("🎮 Phase changed to: #{new_phase}")

    # Fetch updated game state when phase changes
    socket = if socket.assigns.current_game_id do
      try do
        game_state = IndiesShuffle.Game.GameServer.get_state(socket.assigns.current_game_id)

        # Update player info if needed
        my_indie_id = socket.assigns.indie_id
        updated_player_info = if my_indie_id && game_state.groups do
          Enum.find_value(game_state.groups, socket.assigns.player_info, fn group ->
            member = Enum.find(group.members, &(&1.indie_id == my_indie_id))
            if member do
              %{
                player_id: my_indie_id,
                group_id: group.id,
                group_emoji: group.emoji,
                group_members: group.members,
                leader_id: group.leader_id
              }
            else
              nil
            end
          end)
        else
          socket.assigns.player_info
        end

        socket
        |> assign(:current_game_state, game_state)
        |> assign(:game_phase, new_phase)
        |> assign(:player_info, updated_player_info)
        |> assign(:finding_team_remaining, game_state.finding_team_remaining || 0)
      catch
        :exit, _ ->
          # If can't get state, just update phase
          assign(socket, game_phase: new_phase)
      end
    else
      assign(socket, game_phase: new_phase)
    end

    {:noreply, socket}
  end

  # Update game state timer
  @impl true
  def handle_info(:update_game_state, socket) do
    if socket.assigns.game_active and socket.assigns.current_game_id do
      try do
        game_state = IndiesShuffle.Game.GameServer.get_state(socket.assigns.current_game_id)

        # Schedule next update if game is active
        if game_state.phase != :waiting do
          Process.send_after(self(), :update_game_state, 1000)
        end

        {:noreply,
         socket
         |> assign(:current_game_state, game_state)
         |> assign(:game_phase, game_state.phase)
         |> assign(:finding_team_remaining, game_state.finding_team_remaining || 0)}
      catch
        :exit, _ ->
          # Game server is down, stop updating
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp list_players do
    Presence.list(@topic)
    |> Enum.map(fn {_id, %{metas: [meta | _]}} ->
      %{indie_id: meta.indie_id, name: meta.name}
    end)
    |> Enum.sort_by(& &1.indie_id)
  end

  defp update_game_state(socket) do
    players_count = length(socket.assigns.players)

    game_state = cond do
      players_count < 1 -> :waiting
      players_count >= 1 -> :ready
      true -> :waiting
    end

    can_start = players_count >= 1

    socket
    |> assign(:game_state, game_state)
    |> assign(:can_start_game, can_start)
    |> assign(:players_needed, max(0, 1 - players_count))
  end

  # This function is now handled by the more comprehensive version below

  defp join_existing_game(socket, game_id, game_state) do
    player = %{
      id: socket.assigns.indie_id,
      indie_id: socket.assigns.indie_id,
      name: socket.assigns.name || "Usuario"
    }

    case IndiesShuffle.Game.GameServer.assign_player_to_group(game_id, player) do
      {:ok, assigned_group} ->
        IO.puts("🎮 User #{socket.assigns.indie_id} successfully joined game #{game_id} in group #{assigned_group.id}")

        # Subscribe to game events
        PubSub.subscribe(IndiesShuffle.PubSub, "game:" <> game_id)

        # Create player info
        player_info = %{
          player_id: socket.assigns.indie_id,
          group_id: assigned_group.id,
          group_emoji: assigned_group.emoji,
          group_members: assigned_group.members,
          leader_id: assigned_group.leader_id
        }

        socket
        |> assign(:game_active, true)
        |> assign(:current_game_id, game_id)
        |> assign(:current_game_state, game_state)
        |> assign(:player_info, player_info)
        |> assign(:my_group, assigned_group)
        |> assign(:my_question, assigned_group.question)
        |> assign(:game_phase, game_state.phase)

      {:error, reason} ->
        IO.puts("⚠️ Failed to join game: #{inspect(reason)}")
        socket
    end
  end

  defp find_active_game() do
    try do
      case DynamicSupervisor.which_children(IndiesShuffle.GameSupervisor) do
        [] ->
          nil
        children ->
          Enum.find_value(children, fn
            {_, pid, :worker, [IndiesShuffle.Game.GameServer]} when is_pid(pid) ->
              try do
                Registry.keys(IndiesShuffle.Registry, pid)
                |> Enum.find_value(fn
                  {:game, game_id} ->
                    try do
                      game_state = IndiesShuffle.Game.GameServer.get_state(game_id)
                      if game_state.phase != :ended do
                        {game_id, game_state}
                      else
                        nil
                      end
                    catch
                      :exit, _ -> nil
                    end
                  _ -> nil
                end)
              catch
                :exit, _ -> nil
              end
            _ ->
              nil
          end)
      end
    catch
      :exit, _ -> nil
    end
  end

  defp check_and_join_active_game(socket) do
    # Only check if user is authenticated and not already in a game
    if socket.assigns.indie_id && socket.assigns.name && !socket.assigns.game_active do
      case find_active_game() do
        {game_id, game_state} ->
          IO.puts("🎮 LobbyLive: Found active game #{game_id}, attempting to join user #{socket.assigns.indie_id}")

          player = %{
            id: socket.assigns.indie_id,
            indie_id: socket.assigns.indie_id,
            name: socket.assigns.name
          }

          case IndiesShuffle.Game.GameServer.assign_player_to_group(game_id, player) do
            {:ok, assigned_group} ->
              IO.puts("✅ User #{socket.assigns.indie_id} successfully joined game #{game_id} in group #{assigned_group.id}")

              # Subscribe to game events
              PubSub.subscribe(IndiesShuffle.PubSub, "game:" <> game_id)

              # Create player info
              player_info = %{
                player_id: socket.assigns.indie_id,
                group_id: assigned_group.id,
                group_emoji: assigned_group.emoji,
                group_members: assigned_group.members,
                leader_id: assigned_group.leader_id
              }

              # Start timer for updating game state
              Process.send_after(self(), :update_game_state, 1000)

              socket
              |> assign(:game_active, true)
              |> assign(:current_game_id, game_id)
              |> assign(:current_game_state, game_state)
              |> assign(:player_info, player_info)
              |> assign(:my_group, assigned_group)
              |> assign(:my_question, assigned_group.question)
              |> assign(:game_phase, game_state.phase)
              |> assign(:finding_team_remaining, game_state.finding_team_remaining || 0)
              |> push_event("save-game-state", %{
                game_id: game_id,
                group_id: assigned_group.id,
                game_phase: game_state.phase,
                mode: game_state.mode
              })

            {:error, reason} ->
              IO.puts("⚠️ Failed to join game: #{inspect(reason)}")
              socket
          end
        nil ->
          socket
      end
    else
      socket
    end
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode32(case: :lower, padding: false)
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end

  defp track_user_presence(socket) do
    if socket.assigns.joined && socket.assigns.name && socket.assigns.indie_id do
      # Usar indie_id como clave única en lugar de token
      # Esto asegura que un usuario solo tenga una entrada en Presence
      {:ok, _} =
        Presence.track(self(), @topic, socket.assigns.indie_id, %{
          indie_id: socket.assigns.indie_id,
          name: socket.assigns.name,
          token: socket.assigns.token,
          joined_at: System.system_time(:second),
          pid: self()
        })
    end
    socket
  end

  # Resetear el estado de la sesión al cerrar sesión
  defp reset_session_state(socket) do
    # Generar nuevo token pero mantener el indie_id
    new_token = generate_token()

    socket
    |> assign(:token, new_token)
    # Mantener el indie_id existente - NO generar uno nuevo
    |> assign(:name, nil)
    |> assign(:joined, false)
    |> assign(:editing, false)
    |> assign(:checking_auth, false)
    |> assign(:players, list_players())
    |> update_game_state()
  end

  # Genera una clase de gradiente basada en la pregunta
  # para que cada pregunta tenga un gradiente diferente
  defp question_gradient(question) do
    # Lista de variantes de gradiente con naranja y negro
    gradients = [
      "bg-gradient-to-br from-orange-500 to-gray-900",
      "bg-gradient-to-bl from-orange-600 to-gray-800",
      "bg-gradient-to-tr from-gray-900 to-orange-500",
      "bg-gradient-to-tl from-gray-800 to-orange-600",
      "bg-gradient-to-r from-orange-500 via-gray-800 to-orange-600",
      "bg-gradient-to-l from-orange-600 via-gray-900 to-orange-500",
      "bg-gradient-to-br from-gray-900 to-orange-600",
      "bg-gradient-to-bl from-orange-500 to-gray-800"
    ]

    # Usar hash de la pregunta para elegir gradiente de forma consistente
    hash = :erlang.phash2(question, length(gradients))
    Enum.at(gradients, hash)
  end
end
