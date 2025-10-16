defmodule IndiesShuffleWeb.LobbyLive do
  use IndiesShuffleWeb, :live_view
  alias IndiesShuffleWeb.Presence
  alias Phoenix.PubSub

  # Embed templates from the lobby_live/ directory
  embed_templates "lobby_live/*"

  @impl true
  def render(assigns) do
    case assigns.view_state do
      :lobby -> index(assigns)
      :finding -> finding(assigns)
      :solving -> solving(assigns)
      :scoring -> scoring(assigns)
      _ -> index(assigns)
    end
  end

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
      |> assign(:players_needed, 2)
      |> assign(:checking_auth, true)  # Nuevo estado para mostrar loading
      |> assign(:show_logout_modal, false)  # Control del modal
      # Estados del juego
      |> assign(:view_state, :lobby)  # :lobby | :finding | :solving | :scoring
      |> assign(:game_id, nil)
      |> assign(:player_info, %{})
      |> assign(:my_rules, [])
      |> assign(:selected_combination, %{figure: nil, color: nil, style: nil})
      |> assign(:submission_status, nil)
      |> assign(:error_message, nil)
      |> assign(:scores, [])
      |> assign(:secret, nil)

    if connected?(socket) do
      PubSub.subscribe(IndiesShuffle.PubSub, @topic)
      # Timeout de seguridad para el loading
      Process.send_after(self(), :auth_timeout, 1000)
    end

    updated_socket =
      socket
      |> assign(:players, list_players())
      |> update_game_state()

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

        # Si el usuario ya estaba unido, actualizar su presencia (NO eliminarla)
        # La función track_user_presence actualizará la metadata sin desconectar
        IO.puts("🔄 Actualizando presencia con nuevo nombre")

        updated_socket =
          socket
          |> assign(:name, cleaned)
          |> assign(:joined, true)
          |> assign(:editing, false)
          |> assign(:checking_auth, false)
          |> track_user_presence()
          |> assign(:players, list_players())
          |> update_game_state()
          |> push_event("save-jwt-cookie", %{jwt: jwt_token})
          |> check_active_game(socket.assigns.indie_id)

        # Notificar al navegador para actualizar localStorage
        Process.send_after(self(), {:push_local_update, cleaned, socket.assigns.indie_id}, 100)

        IO.puts("✅ Nombre actualizado exitosamente a: #{cleaned}")
        {:noreply, updated_socket}
      else
        IO.puts("❌ Error generando JWT")
        {:noreply, socket}
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
    IO.puts("🖊️ Usuario #{socket.assigns.name} (#{socket.assigns.indie_id}) quiere editar su nombre")
    {:noreply, assign(socket, :editing, true)}
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

            # Verificar si el usuario ya está en Presence y usar el mismo token para evitar duplicados
            existing_token = find_existing_user_token(indie_id) || generate_token()
            IO.puts("🎫 Token usado: #{existing_token}")

            updated_socket =
              socket
              |> assign(:name, name)
              |> assign(:token, existing_token)
              |> assign(:indie_id, indie_id)
              |> assign(:joined, true)
              |> assign(:checking_auth, false)
              |> track_user_presence()
              |> assign(:players, list_players())
              |> update_game_state()
              |> check_active_game(indie_id)

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
  def handle_event("confirm_logout", _, socket) do
    IO.puts("🚪 Usuario cerrando sesión: #{socket.assigns.name || "Anónimo"}")

    # Limpiar presence si el usuario estaba conectado
    if socket.assigns.joined and socket.assigns.token do
      Presence.untrack(self(), @topic, socket.assigns.token)
    end

    updated_socket =
      socket
      |> reset_session_state()
      |> assign(:show_logout_modal, false)
      |> push_event("clear-all-auth", %{})
      |> put_flash(:info, "Sesión cerrada correctamente")

    {:noreply, updated_socket}
  end

  # Game interaction events
  @impl true
  def handle_event("select_figure", %{"figure" => figure}, socket) do
    figure_atom = String.to_existing_atom(figure)
    updated_combination = Map.put(socket.assigns.selected_combination, :figure, figure_atom)
    {:noreply, assign(socket, selected_combination: updated_combination)}
  end

  @impl true
  def handle_event("select_color", %{"color" => color}, socket) do
    color_atom = String.to_existing_atom(color)
    updated_combination = Map.put(socket.assigns.selected_combination, :color, color_atom)
    {:noreply, assign(socket, selected_combination: updated_combination)}
  end

  @impl true
  def handle_event("select_style", %{"style" => style}, socket) do
    style_atom = String.to_existing_atom(style)
    updated_combination = Map.put(socket.assigns.selected_combination, :style, style_atom)
    {:noreply, assign(socket, selected_combination: updated_combination)}
  end

  @impl true
  def handle_event("submit_answer", _params, socket) do
    if socket.assigns.player_info.is_leader and
       socket.assigns.view_state == :solving and
       combination_complete?(socket.assigns.selected_combination) do

      case IndiesShuffle.Game.GameServer.submit_answer(
        socket.assigns.game_id,
        socket.assigns.player_info.group_id,
        socket.assigns.player_info.player_id,
        socket.assigns.selected_combination
      ) do
        {:ok, is_correct} ->
          status = if is_correct, do: :correct, else: :incorrect
          socket = assign(socket, submission_status: status)
          {:noreply, put_flash(socket, :info, "¡Respuesta enviada!")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(error_message: reason)
           |> put_flash(:error, "Error al enviar: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No puedes enviar la respuesta")}
    end
  end

  @impl true
  def handle_event("reset_combination", _params, socket) do
    reset_combination = %{figure: nil, color: nil, style: nil}
    {:noreply, assign(socket, selected_combination: reset_combination)}
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

    # Remover de Presence temporalmente, pero mantener la sesión
    if socket.assigns.joined and socket.assigns.token do
      Presence.untrack(self(), @topic, socket.assigns.token)
    end

    # NO resetear la sesión ni limpiar auth - solo remover de Presence
    {:noreply,
     socket
     |> assign(:joined, false)
     |> put_flash(:error, message)}
  end

  # Handle admin ban
  @impl true
  def handle_info({:admin_ban, message}, socket) do
    IO.puts("🚫 Admin ban: #{message}")

    # Remover de Presence y limpiar sesión solo si es ban permanente
    if socket.assigns.joined and socket.assigns.token do
      Presence.untrack(self(), @topic, socket.assigns.token)
    end

    # Limpiar completamente la sesión solo en caso de ban
    {:noreply,
     socket
     |> reset_session_state()
     |> put_flash(:error, message)
     |> push_event("clear-all-auth", %{})}
  end

  # Handle game starting - change view state instead of redirecting
  @impl true
  def handle_info({:game_starting, game_id}, socket) do
    IO.puts("🎮 Game starting! Changing to finding phase for game #{game_id}")

    # Suscribirse al canal del juego
    PubSub.subscribe(IndiesShuffle.PubSub, "game:#{game_id}")

    # Obtener información del jugador del juego
    player_info = get_player_info_from_game(game_id, socket.assigns.indie_id)
    my_rules = Map.get(player_info, :rules, [])

    IO.puts("🎯 Player info: #{inspect(player_info)}")
    IO.puts("📜 My rules: #{inspect(my_rules)}")

    {:noreply,
     socket
     |> assign(:view_state, :finding)
     |> assign(:game_id, game_id)
     |> assign(:player_info, player_info)
     |> assign(:my_rules, my_rules)}
  end

  # Handle phase changes
  @impl true
  def handle_info({:phase_change, phase}, socket) do
    IO.puts("📡 Phase change: #{phase}")

    {:noreply, assign(socket, :view_state, phase)}
  end

  # Handle game events
  @impl true
  def handle_info({:game_event, event}, socket) do
    IO.puts("🎲 Game event: #{inspect(event)}")

    case event do
      {:answer_submitted, _group_id, is_correct} ->
        status = if is_correct, do: :correct, else: :incorrect
        {:noreply, assign(socket, :submission_status, status)}

      {:final_scores, scores, secret} ->
        {:noreply,
         socket
         |> assign(:scores, scores)
         |> assign(:secret, secret)}

      {:game_ended} ->
        IO.puts("🏁 Juego terminado, volviendo al lobby pero manteniendo sesión")
        {:noreply,
         socket
         |> assign(:view_state, :lobby)
         |> assign(:game_id, nil)
         |> assign(:player_info, %{})
         |> assign(:my_rules, [])
         |> assign(:selected_combination, %{figure: nil, color: nil, style: nil})
         |> assign(:submission_status, nil)
         |> assign(:scores, [])
         |> assign(:secret, nil)}

      _ ->
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
      players_count < 2 -> :waiting
      players_count >= 2 and players_count < 24 -> :ready
      players_count >= 24 -> :full
      true -> :waiting
    end

    socket
    |> assign(:game_state, game_state)
    |> assign(:players_needed, max(0, 2 - players_count))
  end

  defp generate_token do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end

  defp track_user_presence(socket) do
    if socket.assigns.joined and socket.assigns.name do
      {:ok, _} =
        Presence.track(self(), @topic, socket.assigns.token, %{
          indie_id: socket.assigns.indie_id,
          name: socket.assigns.name,
          token: socket.assigns.token,
          joined_at: System.system_time(:second),
          pid: self()
        })
    end
    socket
  end

  # Buscar si un usuario ya está conectado y obtener su token para evitar duplicados
  defp find_existing_user_token(indie_id) do
    Presence.list(@topic)
    |> Enum.find_value(fn {_token, %{metas: metas}} ->
      case Enum.find(metas, &(&1.indie_id == indie_id)) do
        %{token: token} -> token
        _ -> nil
      end
    end)
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

  # Verificar si hay un juego activo y reconectar al jugador
  defp check_active_game(socket, player_id) do
    try do
      # Buscar todos los procesos de juegos en el Registry
      active_games = Registry.select(IndiesShuffle.Registry, [
        {{{:game, :"$1"}, :"$2", :_}, [], [{{:"$1", :"$2"}}]}
      ])

      IO.puts("🔍 Buscando juego activo para jugador #{player_id} entre #{length(active_games)} juegos")

      # Buscar el juego donde está el jugador
      active_game = Enum.find_value(active_games, fn {game_id, _pid} ->
        try do
          game_state = IndiesShuffle.Game.GameServer.get_state(game_id)

          # Verificar si el jugador está en este juego y el juego está activo
          if game_state.phase in [:finding, :solving, :scoring] do
            player_in_game? = Enum.any?(game_state.groups, fn group ->
              Enum.any?(group.members, fn member ->
                Map.get(member, :indie_id) == player_id || Map.get(member, :id) == player_id
              end)
            end)

            if player_in_game? do
              IO.puts("✅ Jugador #{player_id} encontrado en juego #{game_id} (fase: #{game_state.phase})")
              {game_id, game_state.phase}
            else
              nil
            end
          else
            nil
          end
        rescue
          error ->
            IO.puts("⚠️ Error al verificar juego #{game_id}: #{inspect(error)}")
            nil
        end
      end)

      case active_game do
        {game_id, phase} ->
          IO.puts("🎮 Reconectando jugador #{player_id} al juego #{game_id} en fase #{phase}")

          # Suscribirse al canal del juego (verificar si ya está suscrito)
          PubSub.subscribe(IndiesShuffle.PubSub, "game:#{game_id}")

          # Obtener información del jugador
          player_info = get_player_info_from_game(game_id, player_id)
          my_rules = Map.get(player_info, :rules, [])

          IO.puts("📋 Info del jugador: grupo=#{player_info.group_id}, rol=#{player_info.role}")

          socket
          |> assign(:view_state, phase)
          |> assign(:game_id, game_id)
          |> assign(:player_info, player_info)
          |> assign(:my_rules, my_rules)

        nil ->
          IO.puts("👤 No hay juego activo para el jugador #{player_id}, permanece en lobby")
          socket
      end
    rescue
      error ->
        IO.puts("❌ Error checking active game: #{inspect(error)}")
        IO.puts("📚 Stack trace: #{Exception.format_stacktrace()}")
        socket
    end
  end

  # Obtener información del jugador del juego
  defp get_player_info_from_game(game_id, player_id) do
    try do
      # Obtener estado del juego
      game_state = IndiesShuffle.Game.GameServer.get_state(game_id)

      # Buscar el grupo del jugador
      player_group = Enum.find(game_state.groups, fn group ->
        Enum.any?(group.members, fn member ->
          Map.get(member, :indie_id) == player_id || Map.get(member, :id) == player_id
        end)
      end)

      if player_group do
        # Encontrar el jugador específico en el grupo
        player_member = Enum.find(player_group.members, fn member ->
          Map.get(member, :indie_id) == player_id || Map.get(member, :id) == player_id
        end)

        # Obtener reglas del jugador
        rules = IndiesShuffle.Game.GameServer.get_player_rules(game_id, player_id)

        %{
          player_id: player_id,
          group_id: player_group.id,
          group_emoji: player_group.emoji,
          group_members: player_group.members,
          leader_id: player_group.leader_id,
          is_leader: player_group.leader_id == player_id,
          role: Map.get(player_member, :role, :solver),
          rules: rules
        }
      else
        %{player_id: player_id, group_id: nil, rules: []}
      end
    rescue
      error ->
        IO.puts("❌ Error getting player info: #{inspect(error)}")
        %{player_id: player_id, group_id: nil, rules: []}
    end
  end

  # Helper functions for game UI
  defp combination_complete?(%{figure: figure, color: color, style: style}) do
    not is_nil(figure) and not is_nil(color) and not is_nil(style)
  end

  defp get_figure_emoji(figure) do
    case figure do
      :circle -> "●"
      :square -> "■"
      :triangle -> "▲"
      :diamond -> "♦"
      :star -> "★"
      :hexagon -> "⬢"
      _ -> "?"
    end
  end

  defp get_color_class(color) do
    case color do
      :red -> "text-red-500"
      :blue -> "text-blue-500"
      :green -> "text-green-500"
      :yellow -> "text-yellow-500"
      :purple -> "text-purple-500"
      :orange -> "text-orange-500"
      _ -> "text-gray-500"
    end
  end

  defp get_style_class(style) do
    case style do
      :filled -> ""
      :outline -> "filter-outline"
      :dashed -> "filter-dashed"
      _ -> ""
    end
  end
end
