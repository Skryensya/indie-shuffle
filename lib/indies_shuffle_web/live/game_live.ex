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
      game_state: %{phase: :waiting, groups: []},
      player_info: %{player_id: nil, group_id: nil, is_leader: false, group_members: []},
      my_rules: [],
      selected_combination: %{figure: nil, color: nil, style: nil},
      submission_status: nil,
      error_message: nil,
      indie_id: nil,
      checking_auth: true
    }

    socket = assign(socket, initial_assigns)

    if connected?(socket) do
      # Subscribe to game events
      PubSub.subscribe(IndiesShuffle.PubSub, "game:" <> game_id)
      # Set a timeout for auth checking
      Process.send_after(self(), :auth_timeout, 2000)
    end

    {:ok, socket}
  end

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
       socket.assigns.game_state.phase == :solving and
       combination_complete?(socket.assigns.selected_combination) do
      
      case GameServer.submit_answer(
        socket.assigns.game_id,
        socket.assigns.player_info.group_id,
        socket.assigns.player_info.player_id,
        socket.assigns.selected_combination
      ) do
        {:ok, is_correct} ->
          status = if is_correct, do: :correct, else: :incorrect
          socket = assign(socket, submission_status: status)
          {:noreply, put_flash(socket, :info, "Answer submitted!")}
        
        {:error, reason} ->
          {:noreply, 
           socket
           |> assign(error_message: reason)
           |> put_flash(:error, "Failed to submit: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Cannot submit answer")}
    end
  end

  @impl true
  def handle_event("reset_combination", _params, socket) do
    reset_combination = %{figure: nil, color: nil, style: nil}
    {:noreply, assign(socket, selected_combination: reset_combination)}
  end

  @impl true
  def handle_event("init_indie_id", %{"indie_id" => indie_id}, socket) do
    # Get current game state with player context
    game_state = GameServer.get_state(socket.assigns.game_id)
    
    # Update socket with indie_id
    socket = assign(socket, indie_id: indie_id, checking_auth: false)
    
    # Determine player's group and role
    player_info = get_player_info(socket, game_state)
    
    # Update socket with game state and player info
    socket = assign(socket, game_state: game_state, player_info: player_info)
    
    # Load player rules if in solving phase
    socket = if game_state.phase == :solving do
      load_player_rules(socket)
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("no_auth_data", _params, socket) do
    {:noreply, assign(socket, checking_auth: false)}
  end

  @impl true
  def handle_info({:game_event, event}, socket) do
    socket = handle_game_event(socket, event)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:phase_change, new_phase}, socket) do
    updated_game_state = Map.put(socket.assigns.game_state, :phase, new_phase)
    socket = assign(socket, game_state: updated_game_state)
    
    socket = case new_phase do
      :solving ->
        load_player_rules(socket)
      :scoring ->
        # Clear any temporary state
        assign(socket, selected_combination: %{figure: nil, color: nil, style: nil})
      _ ->
        socket
    end

    {:noreply, socket}
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
  def render(assigns) do
    if assigns.checking_auth do
      checking_auth(assigns)
    else
      case assigns.game_state.phase do
        :waiting -> waiting(assigns)
        :finding -> finding(assigns)
        :solving -> solving(assigns)
        :scoring -> scoring(assigns)
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
        %{
          player_id: player_id,
          group_id: nil,
          group_emoji: nil,
          is_leader: false,
          group_members: []
        }
      
      group ->
        %{
          player_id: player_id,
          group_id: group.id,
          group_emoji: group.emoji,
          is_leader: group.leader_id == player_id,
          group_members: group.members
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

  defp load_player_rules(socket) do
    rules = GameServer.get_player_rules(socket.assigns.game_id, socket.assigns.player_info.player_id)
    assign(socket, my_rules: rules)
  end

  defp combination_complete?(%{figure: figure, color: color, style: style}) do
    not is_nil(figure) and not is_nil(color) and not is_nil(style)
  end

  defp handle_game_event(socket, event) do
    case event do
      {:answer_submitted, group_id, is_correct} ->
        if group_id == socket.assigns.player_info.group_id do
          status = if is_correct, do: :correct, else: :incorrect
          assign(socket, submission_status: status)
        else
          socket
        end

      {:final_scores, scores, secret} ->
        socket
        |> assign(scores: scores)
        |> assign(secret: secret)

      {:player_disconnected, _player_id} ->
        # Refresh game state to update group information
        game_state = GameServer.get_state(socket.assigns.game_id)
        assign(socket, game_state: game_state)

      _ ->
        socket
    end
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