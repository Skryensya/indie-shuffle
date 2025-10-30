defmodule IndiesShuffleWeb.GameLive do
  use IndiesShuffleWeb, :live_view
  alias IndiesShuffle.Game.GameServer
  alias Phoenix.PubSub

  embed_templates "game_live/*"

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    # Initialize with basic game state
    initial_assigns = %{
      game_id: game_id,
      game_state: %{phase: :waiting, mode: "groups", groups: [], question: nil, finding_team_remaining: 0},
      player_info: %{player_id: nil, group_id: nil, is_leader: false, group_members: [], leader_id: nil},
      indie_id: nil,
      checking_auth: true
    }

    socket = assign(socket, initial_assigns)

    if connected?(socket) do
      # Subscribe to game events
      PubSub.subscribe(IndiesShuffle.PubSub, "game:" <> game_id)

      # Get current game state immediately
      socket = try do
        game_state = GameServer.get_state(game_id)
        player_info = get_player_info(socket, game_state)
        assign(socket, game_state: game_state, player_info: player_info)
      catch
        :exit, _ ->
          # If game doesn't exist, keep initial state
          IO.puts("GameLive: Game #{game_id} not found on mount, waiting for game to start")
          socket
      end

      # Set a timeout for auth checking
      Process.send_after(self(), :auth_timeout, 2000)
      # Start timer for updating game state
      Process.send_after(self(), :update_game_state, 1000)

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event("init_indie_id", %{"indie_id" => indie_id}, socket) do
    # Get current game state with player context
    socket = assign(socket, indie_id: indie_id, checking_auth: false)

    socket = try do
      game_state = GameServer.get_state(socket.assigns.game_id)
      # Determine player's group and role
      player_info = get_player_info(socket, game_state)

      # Update socket with game state and player info
      socket = assign(socket, game_state: game_state, player_info: player_info)

      # Start updates immediately if game is active
      if game_state.phase != :waiting do
        Process.send_after(self(), :update_game_state, 500)
      end

      socket
    catch
      :exit, _ ->
        IO.puts("GameLive: Game not found in init_indie_id, waiting for game_started event")
        socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("no_auth_data", _params, socket) do
    # When no auth data, still try to get current game state
    socket = try do
      game_state = GameServer.get_state(socket.assigns.game_id)
      player_info = get_player_info(socket, game_state)
      assign(socket, game_state: game_state, player_info: player_info, checking_auth: false)
    catch
      :exit, _ ->
        assign(socket, checking_auth: false)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("return_to_lobby", _params, socket) do
    {:noreply, push_navigate(socket, to: "/")}
  end

  @impl true
  def handle_info({:game_event, event}, socket) do
    socket = handle_game_event(socket, event)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:phase_change, _new_phase}, socket) do
    # Get fresh game state when phase changes
    try do
      game_state = GameServer.get_state(socket.assigns.game_id)
      player_info = get_player_info(socket, game_state)
      {:noreply, assign(socket, game_state: game_state, player_info: player_info)}
    catch
      :exit, _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:auth_timeout, socket) do
    # Timeout de seguridad - desactivar loading si aún está activo
    if socket.assigns.checking_auth do
      {:noreply, assign(socket, checking_auth: false)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:update_game_state, socket) do
    # Get updated game state to show timer
    try do
      game_state = GameServer.get_state(socket.assigns.game_id)
      player_info = get_player_info(socket, game_state)

      # Schedule next update if game is active (not :waiting)
      if game_state.phase != :waiting do
        Process.send_after(self(), :update_game_state, 1000)
      end

      {:noreply, assign(socket, game_state: game_state, player_info: player_info)}
    catch
      :exit, _ ->
        # If game server is down, stop updating
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    if assigns.checking_auth do
      checking_auth(assigns)
    else
      case assigns.game_state.phase do
        :waiting -> waiting(assigns)
        :finding -> finding(assigns)
        :finding_team -> solving(assigns)  # Use solving template to show timer in question space
        :question -> solving(assigns)  # Reusing solving template for question display
        :ended -> ended(assigns)  # Show thank you screen
        _ -> waiting(assigns)
      end
    end
  end

  # === Helper Functions ===

  defp get_player_info(socket, game_state) do
    player_id = get_player_id(socket)

    # Find player's group
    player_group = Enum.find(game_state.groups, fn group ->
      Enum.any?(group.members, &(&1.indie_id == player_id))
    end)

    case player_group do
      nil ->
        # If player is not in a group yet, try to find them in any group for emoji
        group_emoji = case game_state.groups do
          [] -> "🔍"  # Default emoji if no groups exist yet
          groups ->
            # Try to find if player has an assigned emoji from any group member data
            found_emoji = groups
            |> Enum.flat_map(& &1.members)
            |> Enum.find(&(&1.indie_id == player_id))
            |> case do
              nil -> List.first(groups).emoji  # Use first group's emoji as fallback
              _member -> List.first(groups).emoji  # Use group's emoji
            end
            found_emoji || "🔍"
        end

        %{
          player_id: player_id,
          group_id: nil,
          group_emoji: group_emoji,
          is_leader: false,
          group_members: [],
          leader_id: nil
        }

      group ->
        %{
          player_id: player_id,
          group_id: group.id,
          group_emoji: group.emoji,
          is_leader: group.leader_id == player_id,
          group_members: group.members,
          leader_id: group.leader_id
        }
    end
  end

  defp get_player_id(socket) do
    # Get from assigns like in LobbyLive, or fallback to socket ID
    case socket.assigns do
      %{indie_id: indie_id} when not is_nil(indie_id) -> indie_id
      %{current_user: %{indie_id: indie_id}} -> indie_id
      _ -> socket.id  # Fallback to socket ID
    end
  end

  defp handle_game_event(socket, event) do
    try do
      case event do
        {:game_started, _mode, _groups} ->
          # Get fresh game state instead of manually updating
          game_state = GameServer.get_state(socket.assigns.game_id)
          player_info = get_player_info(socket, game_state)
          assign(socket, game_state: game_state, player_info: player_info)

        {:questions_revealed, _groups_with_questions} ->
          # When questions are revealed after finding_team timer (legacy)
          game_state = GameServer.get_state(socket.assigns.game_id)
          player_info = get_player_info(socket, game_state)
          assign(socket, game_state: game_state, player_info: player_info)

        {:game_ended} ->
          # Show thank you screen instead of redirecting immediately
          game_state = Map.put(socket.assigns.game_state, :phase, :ended)
          assign(socket, game_state: game_state)

        {:player_disconnected, _player_id} ->
          # Refresh game state to update group information
          game_state = GameServer.get_state(socket.assigns.game_id)
          player_info = get_player_info(socket, game_state)
          assign(socket, game_state: game_state, player_info: player_info)

        {:phase_change, _new_phase} ->
          # Refresh complete game state on phase change
          game_state = GameServer.get_state(socket.assigns.game_id)
          player_info = get_player_info(socket, game_state)
          assign(socket, game_state: game_state, player_info: player_info)

        _ ->
          socket
      end
    catch
      :exit, _ ->
        IO.puts("GameLive: Error getting game state in handle_game_event")
        socket
    end
  end
end
