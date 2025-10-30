defmodule IndiesShuffle.Game.GameServer do
  @moduledoc """
  Main game server that manages game state, phases, and player interactions.
  Groups players and presents them with discussion questions.
  """

  use GenServer
  alias IndiesShuffle.Game.{Questions, Grouping}
  alias IndiesShuffleWeb.Presence

  @topic_prefix "game:"
  @lobby_topic "lobby:presence"

  # === Public API ===

  @doc """
  Starts a new game server for the given game ID and mode.
  """
  def start_link({game_id, mode}) do
    GenServer.start_link(__MODULE__, {game_id, mode}, name: via_tuple(game_id))
  end

  @doc """
  Child spec for DynamicSupervisor.
  """
  def child_spec({game_id, mode}) do
    %{
      id: {__MODULE__, game_id},
      start: {__MODULE__, :start_link, [{game_id, mode}]},
      restart: :temporary,
      type: :worker
    }
  end

  @doc """
  Starts the game with current lobby players.
  """
  def start_game(game_id) do
    GenServer.cast(via_tuple(game_id), :start_game)
  end

  @doc """
  Gets the current game state.
  """
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  @doc """
  Handles player disconnection.
  """
  def player_disconnected(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:player_disconnected, player_id})
  end

  @doc """
  Ends the current game.
  """
  def end_game(game_id) do
    GenServer.cast(via_tuple(game_id), :end_game)
  end

  @doc """
  Assigns new questions to all groups and reshuffles groups avoiding previous pairings.
  If specific_question is provided, uses that question for all groups, otherwise random.
  enable_timer: whether to use the finding team timer
  enable_regrouping: whether to regroup players or keep current groups
  """
  def next_question(game_id, specific_question \\ nil, enable_timer \\ true, enable_regrouping \\ true) do
    GenServer.cast(via_tuple(game_id), {:next_question, specific_question, enable_timer, enable_regrouping})
  end

  @doc """
  Skips the finding team timer and immediately starts the question phase.
  """
  def skip_finding_team(game_id) do
    GenServer.cast(via_tuple(game_id), :skip_finding_team)
  end

  @doc """
  Assigns a new player to a group during an active game.
  Assigns to the group with the fewest members, or randomly if tied.
  """
  def assign_player_to_group(game_id, player) do
    GenServer.call(via_tuple(game_id), {:assign_player, player})
  end

  # === GenServer Callbacks ===

  @impl true
  def init({game_id, mode}) do
    initial_state = %{
      id: game_id,
      mode: mode,
      phase: :waiting,
      groups: [],
      question: nil,
      disconnected_players: MapSet.new(),
      start_time: nil,
      phase_timers: %{},
      group_history: [],  # Track all group combinations to avoid repetitions
      finding_team_timer: nil,
      finding_team_start_time: nil
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_cast(:start_game, state) do
    IO.puts("GameServer: handle_cast(:start_game) called for game #{state.id}")
    players = fetch_lobby_players()
    IO.puts("GameServer: Found #{length(players)} players: #{inspect(players)}")

    if length(players) >= 1 do
      # Create groups based on mode WITH questions immediately
      groups = case state.mode do
        "together" ->
          # All players in one big group WITH question
          question = Questions.random_question()
          IO.puts("GameServer: Creating 'together' group with question: #{question}")
          [%{
            id: "group_all",
            emoji: "🎯",
            leader_id: nil,  # No leader in together mode
            members: players,
            question: question  # Add question immediately
          }]
        _ ->
          # Separate into groups WITH questions immediately
          IO.puts("GameServer: Creating groups mode")
          initial_groups = Grouping.group_players(players)
          IO.puts("✅ Created #{length(initial_groups)} initial groups")

          initial_groups
          |> Enum.map(fn group ->
            member_names = Enum.map(group.members, & &1.name) |> Enum.join(", ")
            IO.puts("  - Group #{group.id} (#{group.emoji}): #{length(group.members)} members - [#{member_names}]")
            question = Questions.random_question()
            IO.puts("    Question: #{question}")
            Map.put(group, :question, question)  # Add question immediately
          end)
      end

      IO.puts("GameServer: Created #{length(groups)} groups in total")

      # Record initial group combinations in history
      new_history = record_group_combinations(state.group_history, groups)

      # Start in finding_team phase with 31 second timer (to ensure 30s is visible)
      finding_team_start = System.system_time(:millisecond)
      timer_ref = Process.send_after(self(), :start_question_phase, 31_000)

      new_state = %{state |
        phase: :finding_team,  # Start with finding team phase
        groups: groups,
        question: nil,  # Question is now per-group
        start_time: finding_team_start,
        group_history: new_history,
        finding_team_timer: timer_ref,
        finding_team_start_time: finding_team_start
      }

      IO.puts("GameServer: Broadcasting game_started event")
      # Broadcast game start with groups (with questions already assigned)
      broadcast_game_to_all(state, {:game_started, state.mode, groups})
      broadcast_phase_change(state.id, :finding_team)  # Start in finding_team phase

      # Also broadcast to lobby so players can redirect to the game
      broadcast_to_lobby({:game_started_redirect, state.id, state.mode, groups})

      {:noreply, new_state}
    else
      IO.puts("GameServer: Not enough players (#{length(players)})")
      broadcast_game_event(state.id, {:error, "Not enough players to start game"})
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:player_disconnected, player_id}, state) do
    new_state = %{state |
      disconnected_players: MapSet.put(state.disconnected_players, player_id)
    }

    broadcast_game_event(state.id, {:player_disconnected, player_id})
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:end_game, state) do
    # Update state to ended phase
    new_state = %{state | phase: :ended}

    # Broadcast phase change to :ended
    broadcast_game_event(new_state.id, {:phase_change, :ended})

    # Broadcast game ended to all players
    broadcast_game_to_all(new_state, {:game_ended})

    # Schedule cleanup after 60 seconds to allow users to see the end screen
    Process.send_after(self(), :cleanup_game, 60_000)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup_game, state) do
    IO.puts("🧹 Cleaning up game #{state.id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    # Calculate remaining time for finding team phase
    finding_team_remaining = if state.phase == :finding_team and state.finding_team_start_time do
      elapsed = System.system_time(:millisecond) - state.finding_team_start_time
      max(0, 31_000 - elapsed)
    else
      0
    end

    public_state = %{
      id: state.id,
      mode: state.mode,
      phase: state.phase,
      groups: state.groups,
      question: state.question,
      start_time: state.start_time,
      finding_team_remaining: finding_team_remaining
    }
    {:reply, public_state, state}
  end

  @impl true
  def handle_call({:assign_player, player}, _from, state) do
    IO.puts("🆕 New player joining game: #{player.name} (#{player.indie_id})")

    # Check if player is already in a group (reconnecting)
    existing_group = Enum.find(state.groups, fn group ->
      Enum.any?(group.members, fn member -> member.indie_id == player.indie_id end)
    end)

    if existing_group do
      IO.puts("♻️ Player already in group #{existing_group.id}, returning existing group")
      {:reply, {:ok, existing_group}, state}
    else
      # Find the minimum member count
      min_count = state.groups
      |> Enum.map(fn group -> length(group.members) end)
      |> Enum.min()

      # Find all groups with the minimum member count
      groups_with_min = state.groups
      |> Enum.with_index()
      |> Enum.filter(fn {group, _idx} -> length(group.members) == min_count end)

      # Randomly select one if there are multiple with same min count
      {target_group, target_index} = Enum.random(groups_with_min)

      IO.puts("📍 Assigning to group #{target_group.id} (#{target_group.emoji}) which has #{length(target_group.members)} members")

      # Add player to the target group
      updated_group = %{target_group | members: target_group.members ++ [player]}

      # Update groups list
      updated_groups = List.replace_at(state.groups, target_index, updated_group)

      new_state = %{state | groups: updated_groups}

      # Broadcast updated groups to all players
      broadcast_game_to_all(new_state, {:game_started, state.mode, updated_groups})

      # Return the assigned group info
      {:reply, {:ok, updated_group}, new_state}
    end
  end

  @impl true
  def handle_cast(:skip_finding_team, state) do
    if state.phase == :finding_team and state.finding_team_timer do
      IO.puts("GameServer: Admin skipping finding_team timer")
      # Cancel the existing timer
      Process.cancel_timer(state.finding_team_timer)
      # Immediately transition to question phase
      send(self(), :start_question_phase)
      {:noreply, state}
    else
      IO.puts("GameServer: Cannot skip timer - not in finding_team phase or no timer")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:start_question_phase, state) do
    # Transition from finding_team to question phase after 31 seconds
    IO.puts("GameServer: Transitioning to question phase after finding_team timer")

    new_state = %{state |
      phase: :question,
      finding_team_timer: nil
    }

    broadcast_phase_change(state.id, :question)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:show_question, state) do
    new_state = %{state | phase: :question}
    broadcast_phase_change(state.id, :question)
    {:noreply, new_state}
  end

  # Handle old format for backward compatibility
  @impl true
  def handle_cast({:next_question, specific_question}, state) do
    # Default values for old calls
    handle_cast({:next_question, specific_question, true, true}, state)
  end

  @impl true
  def handle_cast({:next_question, specific_question, enable_timer, enable_regrouping}, state) do
    # Wrap entire function in try-catch to prevent crashes
    try do
      # Reduced logging for better performance
      IO.puts("🔄 NEXT QUESTION - Reorganizing groups...")

      # Cancel any existing finding team timer
      if state.finding_team_timer do
        Process.cancel_timer(state.finding_team_timer)
      end

      # Get current players (those not disconnected)
      current_players = get_current_players(state)
      IO.puts("📊 Active players: #{length(current_players)}")

      # If no players, don't proceed
      if length(current_players) == 0 do
        IO.puts("⚠️ No active players found, ending game")
        new_state = %{state | phase: :ended}
        broadcast_game_event(new_state.id, {:phase_change, :ended})
        broadcast_game_to_all(new_state, {:game_ended})
        Process.send_after(self(), :cleanup_game, 60_000)
        {:noreply, new_state}
      else
        # Reshuffle groups avoiding previous pairings (or keep current groups if regrouping disabled)
        new_groups = if enable_regrouping do
          case state.mode do
            "together" ->
              IO.puts("👥 Mode: Together - All players in one group")
              # All players in one big group
              [%{
                id: "group_all",
                emoji: "🎯",
                leader_id: nil,
                members: current_players,
                question: nil  # Will be assigned below
              }]
            _ ->
              IO.puts("\n🔀 REORGANIZANDO GRUPOS (evitando parejas anteriores)...")
              IO.puts("📜 Historial: #{MapSet.size(state.group_history)} parejas registradas")
              IO.puts("📦 Grupos anteriores: #{length(state.groups)}")

              # Reshuffle into new groups avoiding previous pairings AND previous group assignments
              new_groups_result = try do
                # Pass previous groups so players can be rotated to different groups
                Grouping.regroup_players(current_players, state.group_history, state.groups)
              rescue
                error ->
                  IO.puts("⚠️ Error in regroup_players: #{inspect(error)}")
                  # Fallback to simple grouping
                  Grouping.group_players(current_players)
              end

              IO.puts("✅ #{length(new_groups_result)} new groups created")

              new_groups_result
              |> Enum.map(fn group ->
                Map.put(group, :question, nil)  # Will be assigned below
              end)
          end
        else
          IO.puts("🚫 Reagrupamiento desactivado - manteniendo grupos actuales")
          # Keep current groups but clear questions
          state.groups
          |> Enum.map(fn group ->
            Map.put(group, :question, nil)  # Will be assigned below
          end)
        end

        # Assign questions immediately to groups
        groups_with_questions = case specific_question do
          nil ->
            # Each group gets a random question
            IO.puts("🎲 Asignando preguntas aleatorias a #{length(new_groups)} grupos")
            result = Enum.map(new_groups, fn group ->
              question = Questions.random_question()
              IO.puts("  📝 Grupo #{group.id}: #{question}")
              Map.put(group, :question, question)
            end)
            result
          question ->
            # All groups get the same specific question
            IO.puts("🎯 Asignando pregunta específica a #{length(new_groups)} grupos: #{question}")
            result = Enum.map(new_groups, fn group ->
              IO.puts("  📝 Grupo #{group.id}: #{question}")
              Map.put(group, :question, question)
            end)
            result
        end

        # Record new group combinations in history (only if regrouping is enabled)
        new_history = if enable_regrouping do
          try do
            record_group_combinations(state.group_history, groups_with_questions)
          rescue
            error ->
              IO.puts("⚠️ Error recording group history: #{inspect(error)}")
              # Keep existing history if recording fails
              state.group_history
          end
        else
          # Keep existing history if not regrouping
          state.group_history
        end

        # Use timer or skip directly to question phase based on enable_timer
        {new_phase, timer_ref, finding_team_start} = if enable_timer do
          IO.puts("⏰ Timer activado - iniciando fase de búsqueda de equipos (31s)")
          # Start in finding_team phase with 31 second timer (to ensure 30s is visible)
          start_time = System.system_time(:millisecond)
          timer = Process.send_after(self(), :start_question_phase, 31_000)
          {:finding_team, timer, start_time}
        else
          IO.puts("🚫 Timer desactivado - saltando DIRECTO a fase :question")
          # Skip timer, go directly to question phase
          {:question, nil, nil}
        end

        IO.puts("📋 Fase establecida: #{new_phase}")

        new_state = %{state |
          phase: new_phase,
          groups: groups_with_questions,
          group_history: new_history,
          finding_team_timer: timer_ref,
          finding_team_start_time: finding_team_start
        }

        # Debug: Log the final state
        IO.puts("🔍 Estado final del juego:")
        IO.puts("  📊 Fase: #{new_state.phase}")
        IO.puts("  📊 Grupos con preguntas:")
        Enum.each(new_state.groups, fn group ->
          IO.puts("    - #{group.id}: #{inspect(Map.get(group, :question))}")
        end)

        # Broadcast new groups with questions
        IO.puts("\n📢 BROADCASTING nuevos grupos a todos los jugadores...")
        IO.puts("📢 Enviando fase: #{new_phase}")
        broadcast_game_to_all(new_state, {:game_started, state.mode, groups_with_questions})
        broadcast_phase_change(state.id, new_phase)  # Start in the determined phase
        IO.puts("📢 Phase change broadcasted: #{new_phase}")

        # Also broadcast to lobby so players can redirect to the game (if they disconnected and reconnected)
        broadcast_to_lobby({:game_started_redirect, state.id, state.mode, groups_with_questions})

        IO.puts("✅ Question reorganization complete!")

        {:noreply, new_state}
      end
    rescue
      error ->
        IO.puts("💥 CRITICAL ERROR in next_question: #{inspect(error)}")
        IO.puts("📊 Stack trace: #{inspect(__STACKTRACE__)}")
        # Broadcast error to admin panel and continue with current state
        broadcast_game_event(state.id, {:error, "Error durante reorganización: #{inspect(error)}"})
        {:noreply, state}
    end
  end

  # === Private Helper Functions ===

  defp via_tuple(game_id) do
    {:via, Registry, {IndiesShuffle.Registry, {:game, game_id}}}
  end

  defp fetch_lobby_players do
    Presence.list(@lobby_topic)
    |> Enum.map(fn {_token, %{metas: [meta | _]}} ->
      %{
        id: meta.indie_id,
        indie_id: meta.indie_id,
        name: meta.name
      }
    end)
  end

  defp broadcast_game_event(game_id, event) do
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      @topic_prefix <> game_id,
      {:game_event, event}
    )
  end

  defp broadcast_game_to_all(state, event) do
    topic = @topic_prefix <> state.id
    IO.puts("GameServer: Broadcasting #{inspect(event)} to topic '#{topic}'")
    # Broadcast to this specific game's channel
    result = Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      topic,
      {:game_event, event}
    )
    IO.puts("GameServer: Broadcast result: #{inspect(result)}")
    result
  end

  defp broadcast_phase_change(game_id, phase) do
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      @topic_prefix <> game_id,
      {:phase_change, phase}
    )
  end

  defp broadcast_to_lobby(event) do
    IO.puts("GameServer: Broadcasting #{inspect(event)} to game:broadcast")
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      "game:broadcast",
      {:game_event, event}
    )
  end

  # Records all player pairings from the current groups into history
  defp record_group_combinations(history, groups) do
    new_pairs = groups
    |> Enum.flat_map(fn group ->
      # For each group, record all pairs of players
      member_ids = Enum.map(group.members, fn m -> m.indie_id end)

      # Generate all unique pairs in this group
      for i <- 0..(length(member_ids) - 1),
          j <- (i + 1)..(length(member_ids) - 1) do
        {Enum.at(member_ids, i), Enum.at(member_ids, j)}
      end
    end)
    |> Enum.map(fn {p1, p2} ->
      # Normalize pairs so they're always in the same order
      if p1 < p2, do: {p1, p2}, else: {p2, p1}
    end)
    |> MapSet.new()

    # Merge with existing history
    existing_history = if is_list(history), do: MapSet.new(history), else: history
    MapSet.union(existing_history, new_pairs)
  end

  # Gets all players currently in groups (excluding disconnected)
  defp get_current_players(state) do
    state.groups
    |> Enum.flat_map(fn group -> group.members end)
    |> Enum.reject(fn player ->
      MapSet.member?(state.disconnected_players, player.indie_id)
    end)
    |> Enum.uniq_by(fn player -> player.indie_id end)
  end
end
