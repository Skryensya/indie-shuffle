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
           |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())}
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
         |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())}
      _ ->
        {:ok, assign(socket, admin_authenticated: false, login_form: to_form(%{}))}
    end
  end

  @impl true
  def handle_event("admin_login", %{"username" => username, "password" => password}, socket) do
    # Read directly from environment variables at runtime
    admin_username = System.get_env("ADMIN_USERNAME") || "admin"
    admin_password = System.get_env("ADMIN_PASSWORD") || "admin123"

    IO.puts("🔐 Login attempt:")
    IO.puts("  Username provided: '#{username}'")
    IO.puts("  Password provided: '#{password}'")
    IO.puts("  Expected username: '#{admin_username}'")
    IO.puts("  Expected password: '#{admin_password}'")

    if username == admin_username and password == admin_password do
      # Authentication successful - create a simple token
      token = create_admin_token()

      {:noreply,
       socket
       |> assign(admin_authenticated: true, login_form: nil)
       |> assign(connected_users: list_connected_users())
       |> assign(banned_users: IndiesShuffle.BanManager.list_banned_users())
       |> put_flash(:info, "Bienvenido al panel de administración")
       |> push_event("set_admin_token", %{token: token})}
    else
      # Authentication failed
      {:noreply,
       socket
       |> assign(login_form: to_form(%{}))
       |> put_flash(:error, "Credenciales incorrectas")}
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
  def handle_event("start_game", _params, socket) do
    players_count = length(socket.assigns.connected_users)

    if players_count >= 2 do
      # Generate a unique game ID
      game_id = generate_game_id()
      
      # Start the game server
      case DynamicSupervisor.start_child(
        IndiesShuffle.GameSupervisor, 
        {IndiesShuffle.Game.GameServer, game_id}
      ) do
        {:ok, _pid} ->
          # Start the game
          IndiesShuffle.Game.GameServer.start_game(game_id)
          
          {:noreply,
           socket
           |> put_flash(:info, "¡Partida iniciada con #{players_count} jugadores! ID: #{game_id}")
           |> push_event("redirect_to_game", %{game_id: game_id})}
        
        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error al iniciar la partida: #{inspect(reason)}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Se necesitan al menos 2 jugadores para empezar")}
    end
  end

  @impl true
  def handle_event("force_end_game", %{"game_id" => game_id}, socket) do
    # Send end game message to the game server
    case Registry.lookup(IndiesShuffle.Registry, {:game, game_id}) do
      [{pid, _}] ->
        send(pid, :end_game)
        {:noreply, put_flash(socket, :info, "Partida #{game_id} terminada forzadamente")}
      
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
    Presence.list(@topic)
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
