defmodule IndiesShuffleWeb.AdminLive do
  use IndiesShuffleWeb, :live_view
  alias IndiesShuffleWeb.Presence
  alias Phoenix.PubSub

  @topic "lobby:presence"

  # Embed templates from the admin_live/ directory
  embed_templates "admin_live/*"

  @impl true
  def mount(_params, session, socket) do
    # Check if user is already authenticated as admin
    socket = assign(socket, current_scope: nil)

    case get_connect_params(socket)["admin_token"] || session["admin_authenticated"] do
      token when is_binary(token) ->
        if verify_admin_token(token) do
          # Subscribe to presence updates if authenticated
          if connected?(socket) do
            PubSub.subscribe(IndiesShuffle.PubSub, @topic)
          end

          {:ok,
           socket
           |> assign(admin_authenticated: true, login_form: nil)
           |> assign(connected_users: list_connected_users())
           |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())
           |> assign(question_form: to_form(%{}))
           |> assign(open_question_menu_id: nil)
           |> assign(game_mode: "groups")
           |> assign(current_game_id: nil)
           |> assign(game_in_progress: false)
           |> assign(current_game_state: nil)
           |> assign(available_questions: IndiesShuffle.Game.Questions.all_questions())}
        else
          {:ok, assign(socket, admin_authenticated: false, login_form: to_form(%{}))}
        end
      true ->
        if connected?(socket) do
          PubSub.subscribe(IndiesShuffle.PubSub, @topic)
        end

        {:ok,
         socket
         |> assign(admin_authenticated: true, login_form: nil)
         |> assign(connected_users: list_connected_users())
         |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())
         |> assign(question_form: to_form(%{}))
         |> assign(open_question_menu_id: nil)
         |> assign(game_mode: "groups")
         |> assign(current_game_id: nil)
         |> assign(game_in_progress: false)
         |> assign(current_game_state: nil)
         |> assign(available_questions: IndiesShuffle.Game.Questions.all_questions())}
      _ ->
        {:ok, assign(socket, admin_authenticated: false, login_form: to_form(%{}))}
    end
  end

  @impl true
  def handle_event("admin_login", %{"username" => username, "password" => password}, socket) do
    IO.puts("🔐 Intento de login admin:")
    IO.puts("  Usuario recibido: #{inspect(username)}")
    IO.puts("  Contraseña recibida: #{String.length(password)} caracteres")

    # Usar credenciales hardcodeadas por simplicidad
    admin_username = "admin"
    admin_password = "admin123"

    IO.puts("  Usuario esperado: #{inspect(admin_username)}")
    IO.puts("  Contraseña esperada: #{admin_password}")

    if username == admin_username and password == admin_password do
      IO.puts("✅ Autenticación exitosa")
      # Authentication successful - create a simple token
      token = create_admin_token()

      {:noreply,
       socket
       |> assign(admin_authenticated: true, login_form: nil)
       |> assign(connected_users: list_connected_users())
       |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())
       |> assign(question_form: to_form(%{}))
       |> assign(open_question_menu_id: nil)
       |> assign(game_mode: "groups")
       |> assign(current_game_id: nil)
       |> assign(game_in_progress: false)
       |> assign(current_game_state: nil)
       |> assign(available_questions: IndiesShuffle.Game.Questions.all_questions())
       |> put_flash(:info, "Bienvenido al panel de administración")
       |> push_event("set_admin_token", %{token: token})}
    else
      IO.puts("❌ Autenticación fallida")
      IO.puts("  Comparación usuario: #{username == admin_username}")
      IO.puts("  Comparación contraseña: #{password == admin_password}")
      # Authentication failed
      {:noreply,
       socket
       |> assign(login_form: to_form(%{}))
       |> put_flash(:error, "Credenciales incorrectas. Usuario esperado: admin, Contraseña: admin123")}
    end
  end

  @impl true
  def handle_event("admin_logout", _params, socket) do
    {:noreply,
     socket
     |> assign(admin_authenticated: false, login_form: to_form(%{}))
     |> push_event("clear_admin_token", %{})
     |> put_flash(:info, "Sesión de administrador cerrada")}
  end

  @impl true
  def handle_event("disconnect_user", %{"token" => token}, socket) do
    # Find the user by token and send disconnect message
    case find_user_by_token(token) do
      {pid, user} when is_pid(pid) ->
        # Send disconnect message to the user's LiveView process
        send(pid, {:admin_disconnect, "Desconectado por el administrador"})

        {:noreply,
         socket
         |> put_flash(:info, "Usuario #{user.name} desconectado")
         |> assign(connected_users: list_connected_users())}

      nil ->
        {:noreply, put_flash(socket, :error, "Usuario no encontrado")}
    end
  end

  @impl true
  def handle_event("ban_user", %{"indie_id" => indie_id, "token" => token}, socket) do
    # Ban the user
    IndiesShuffle.BanManager.ban_user(indie_id)

    # Also disconnect them if they're connected
    case find_user_by_token(token) do
      {pid, _user} when is_pid(pid) ->
        send(pid, {:admin_ban, "Has sido baneado por el administrador"})
      _ -> :ok
    end

    {:noreply,
     socket
     |> put_flash(:info, "Usuario baneado exitosamente")
     |> assign(connected_users: list_connected_users())
     |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())}
  end

  @impl true
  def handle_event("unban_user", %{"indie_id" => indie_id}, socket) do
    IndiesShuffle.BanManager.unban_user(indie_id)

    {:noreply,
     socket
     |> put_flash(:info, "Usuario desbaneado exitosamente")
     |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())}
  end

  @impl true
  def handle_event("select_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, game_mode: mode)}
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    players_count = length(socket.assigns.connected_users)
    game_mode = socket.assigns.game_mode

    IO.puts("AdminLive: Attempting to start game with #{players_count} players in mode #{game_mode}")

    if players_count >= 1 do
      # Generate a unique game ID
      game_id = generate_game_id()
      IO.puts("AdminLive: Generated game_id: #{game_id}")

      # Start the game server with mode
      case DynamicSupervisor.start_child(
        IndiesShuffle.GameSupervisor,
        {IndiesShuffle.Game.GameServer, {game_id, game_mode}}
      ) do
        {:ok, _pid} ->
          IO.puts("AdminLive: GameServer started successfully, calling start_game")
          # Start the game
          IndiesShuffle.Game.GameServer.start_game(game_id)
          IO.puts("AdminLive: start_game called successfully")

          mode_text = if game_mode == "groups", do: "grupos", else: "todos juntos"
          {:noreply,
           socket
           |> assign(current_game_id: game_id)
           |> assign(game_in_progress: true)
           |> assign(current_game_state: nil)
           |> schedule_game_state_update()
           |> put_flash(:info, "¡Partida iniciada con #{players_count} jugadores en modo #{mode_text}!")}

        {:error, reason} ->
          IO.puts("AdminLive: Error starting GameServer: #{inspect(reason)}")
          {:noreply,
           socket
           |> put_flash(:error, "Error al iniciar la partida: #{inspect(reason)}")}
      end
    else
      IO.puts("AdminLive: Not enough players (#{players_count})")
      {:noreply,
       socket
       |> put_flash(:error, "Se necesita al menos 1 jugador para empezar")}
    end
  end

  @impl true
  def handle_event("end_game", _params, socket) do
    game_id = socket.assigns.current_game_id

    if game_id do
      case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
        [{_pid, _}] ->
          IndiesShuffle.Game.GameServer.end_game(game_id)
          {:noreply,
           socket
           |> assign(current_game_id: nil)
           |> assign(game_in_progress: false)
           |> put_flash(:info, "Partida terminada")}

        [] ->
          {:noreply,
           socket
           |> assign(current_game_id: nil)
           |> assign(game_in_progress: false)
           |> put_flash(:error, "Partida no encontrada")}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay partida activa")}
    end
  end

  @impl true
  def handle_event("next_question_random", _params, socket) do
    game_id = socket.assigns.current_game_id

    if game_id do
      case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
        [{_pid, _}] ->
          IndiesShuffle.Game.GameServer.next_question(game_id, nil)
          {:noreply, put_flash(socket, :info, "Nuevos grupos y pregunta aleatoria asignados")}

        [] ->
          {:noreply, put_flash(socket, :error, "Partida no encontrada")}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay partida activa")}
    end
  end

  @impl true
  def handle_event("next_question_specific", %{"question" => question}, socket) do
    game_id = socket.assigns.current_game_id

    if game_id do
      case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
        [{_pid, _}] ->
          IndiesShuffle.Game.GameServer.next_question(game_id, question)
          {:noreply, put_flash(socket, :info, "Nuevos grupos y pregunta específica asignados")}

        [] ->
          {:noreply, put_flash(socket, :error, "Partida no encontrada")}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay partida activa")}
    end
  end

  @impl true
  def handle_event("skip_finding_team", _params, socket) do
    game_id = socket.assigns.current_game_id

    if game_id do
      case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
        [{_pid, _}] ->
          IndiesShuffle.Game.GameServer.skip_finding_team(game_id)
          {:noreply, put_flash(socket, :info, "Timer saltado, mostrando pregunta ahora")}

        [] ->
          {:noreply, put_flash(socket, :error, "Partida no encontrada")}
      end
    else
      {:noreply, put_flash(socket, :error, "No hay partida activa")}
    end
  end

  @impl true
  def handle_event("create_mock_users", %{"count" => count_str}, socket) do
    case Integer.parse(count_str) do
      {count, _} when count > 0 and count <= 1000 ->
        case IndiesShuffle.MockUsers.create_mock_users(count) do
          {:ok, created} ->
            {:noreply,
             socket
             |> assign(connected_users: list_connected_users())
             |> put_flash(:info, "✅ Creados #{created} usuarios mock")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Número inválido. Debe ser entre 1 y 1000")}
    end
  end

  @impl true
  def handle_event("clear_mock_users", _params, socket) do
    case IndiesShuffle.MockUsers.clear_mock_users() do
      {:ok, cleared} ->
        {:noreply,
         socket
         |> assign(connected_users: list_connected_users())
         |> put_flash(:info, "🧹 Eliminados #{cleared} usuarios mock")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("force_end_game", %{"game_id" => game_id}, socket) do
    # Send end game message to the game server
    case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
      [{pid, _}] ->
        send(pid, :end_game)

        {:noreply,
         socket
         |> put_flash(:info, "Partida #{game_id} terminada forzadamente")
         |> assign(game_in_progress: false, current_game_id: nil)}

      [] ->
        {:noreply, put_flash(socket, :error, "Partida no encontrada")}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, connected_users: list_connected_users())}
  end

  # Helper functions for token management
  defp create_admin_token do
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end

  defp verify_admin_token(token) when is_binary(token) do
    # Simple verification - in production you might want to store tokens in a database
    # or use a more sophisticated token system
    String.length(token) > 10
  end

  defp verify_admin_token(_), do: false

  # Helper functions for managing connected users
  defp list_connected_users do
    users = Presence.list(@topic)
    |> Enum.map(fn {token, %{metas: metas}} ->
      case List.first(metas) do
        %{indie_id: indie_id, name: name, pid: pid} = meta ->
          %{
            token: token,
            indie_id: indie_id,
            name: name,
            pid: pid,
            joined_at: Map.get(meta, :joined_at, System.system_time(:second)),
            is_banned: IndiesShuffle.BanManager.is_banned?(indie_id)
          }
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.joined_at, :desc)

    IO.puts("AdminLive: Found #{length(users)} connected users: #{inspect(Enum.map(users, & &1.name))}")
    users
  end

  defp find_user_by_token(token) do
    case Presence.get_by_key(@topic, token) do
      %{metas: [%{pid: pid} = meta | _]} -> {pid, meta}
      _ -> nil
    end
  end

  defp generate_game_id do
    :crypto.strong_rand_bytes(8) |> Base.encode32(case: :lower, padding: false)
  end

  defp schedule_game_state_update(socket) do
    Process.send_after(self(), :update_game_state, 1000)
    socket
  end

  @impl true
  def handle_info(:update_game_state, socket) do
    if socket.assigns.game_in_progress and socket.assigns.current_game_id do
      case Registry.lookup(IndiesShuffle.Registry, {:game, socket.assigns.current_game_id}) do
        [{_pid, _}] ->
          game_state = IndiesShuffle.Game.GameServer.get_state(socket.assigns.current_game_id)
          # Schedule next update
          Process.send_after(self(), :update_game_state, 1000)
          {:noreply, assign(socket, current_game_state: game_state)}
        [] ->
          # Game ended
          {:noreply,
           socket
           |> assign(game_in_progress: false, current_game_id: nil, current_game_state: nil)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @admin_authenticated do %>
      <%= dashboard(assigns) %>
    <% else %>
      <%= login(assigns) %>
    <% end %>
    """
  end
end
