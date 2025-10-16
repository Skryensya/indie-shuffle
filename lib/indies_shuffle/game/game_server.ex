defmodule IndiesShuffle.Game.GameServer do
  @moduledoc """
  Main game server that manages game state, phases, and player interactions.
  Handles the complete game lifecycle from player grouping to scoring.
  """

  use GenServer
  alias IndiesShuffle.Game.{PuzzleEngine, Grouping}
  alias IndiesShuffleWeb.Presence

  @topic_prefix "game:"
  @lobby_topic "lobby:presence"

  # Phase durations in milliseconds
  @finding_duration 20_000    # 20 seconds to find group members
  @solving_duration 300_000   # 5 minutes to solve puzzle
  @scoring_duration 10_000    # 10 seconds to show results

  # === Public API ===

  @doc """
  Starts a new game server for the given game ID.
  """
  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  @doc """
  Child spec for DynamicSupervisor.
  """
  def child_spec(game_id) do
    %{
      id: {__MODULE__, game_id},
      start: {__MODULE__, :start_link, [game_id]},
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
  Submits an answer from a group leader.
  """
  def submit_answer(game_id, group_id, leader_id, combination) do
    GenServer.call(via_tuple(game_id), {:submit_answer, group_id, leader_id, combination})
  end

  @doc """
  Gets the current game state.
  """
  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  @doc """
  Gets rules for a specific player.
  """
  def get_player_rules(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:get_player_rules, player_id})
  end

  @doc """
  Handles player disconnection.
  """
  def player_disconnected(game_id, player_id) do
    GenServer.cast(via_tuple(game_id), {:player_disconnected, player_id})
  end

  # === GenServer Callbacks ===

  @impl true
  def init(game_id) do
    initial_state = %{
      id: game_id,
      phase: :waiting,
      groups: [],
      secret: nil,
      rules: [],
      rules_by_player: %{},
      answers: %{},
      scores: %{},
      disconnected_players: MapSet.new(),
      start_time: nil,
      phase_timers: %{}
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_cast(:start_game, state) do
    players = fetch_lobby_players()

    if Grouping.sufficient_players?(length(players)) do
      groups = Grouping.group_players(players)
      secret = PuzzleEngine.random_secret()
      rules = PuzzleEngine.generate_rules(secret)

      # Distribute rules among all players
      rules_by_player = distribute_rules_to_players(groups, rules)

      new_state = %{state |
        phase: :finding,
        groups: groups,
        secret: secret,
        rules: rules,
        rules_by_player: rules_by_player,
        start_time: System.system_time(:millisecond)
      }

      # Broadcast game start to lobby to redirect all players
      broadcast_to_lobby({:game_starting, state.id})

      # Broadcast game start to game channel
      broadcast_game_event(state.id, {:game_started, groups})
      broadcast_phase_change(state.id, :finding)

      # Schedule next phase
      timer_ref = Process.send_after(self(), :move_to_solving, @finding_duration)
      new_state = put_in(new_state.phase_timers[:finding], timer_ref)

      {:noreply, new_state}
    else
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
  def handle_call(:get_state, _from, state) do
    public_state = %{
      id: state.id,
      phase: state.phase,
      groups: state.groups,
      answers: state.answers,
      scores: state.scores,
      start_time: state.start_time
    }
    {:reply, public_state, state}
  end

  @impl true
  def handle_call({:get_player_rules, player_id}, _from, state) do
    rules = Map.get(state.rules_by_player, player_id, [])
    {:reply, rules, state}
  end

  @impl true
  def handle_call({:submit_answer, group_id, leader_id, combination}, _from, state) do
    case validate_answer_submission(state, group_id, leader_id, combination) do
      :ok ->
        is_correct = combination == state.secret

        new_answers = Map.put(state.answers, group_id, %{
          combination: combination,
          is_correct: is_correct,
          submitted_at: System.system_time(:millisecond),
          leader_id: leader_id
        })

        new_state = %{state | answers: new_answers}

        broadcast_game_event(state.id, {:answer_submitted, group_id, is_correct})

        # Check if all groups have answered
        if all_groups_answered?(new_state) do
          move_to_scoring(new_state)
        else
          {:reply, {:ok, is_correct}, new_state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:move_to_solving, state) do
    new_state = %{state | phase: :solving}
    broadcast_phase_change(state.id, :solving)

    # Schedule scoring phase
    timer_ref = Process.send_after(self(), :move_to_scoring, @solving_duration)
    new_state = put_in(new_state.phase_timers[:solving], timer_ref)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:move_to_scoring, state) do
    move_to_scoring(state)
  end

  @impl true
  def handle_info(:end_game, state) do
    # Notificar a todos que el juego ha terminado
    broadcast_game_event(state.id, {:game_ended})
    broadcast_phase_change(state.id, :waiting)

    # Clean up and prepare for new game
    new_state = %{state |
      phase: :waiting,
      groups: [],
      secret: nil,
      rules: [],
      rules_by_player: %{},
      answers: %{},
      scores: %{},
      disconnected_players: MapSet.new(),
      start_time: nil,
      phase_timers: %{}
    }

    {:noreply, new_state}
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

  defp distribute_rules_to_players(groups, rules) do
    Enum.reduce(groups, %{}, fn group, acc ->
      group_rules = Grouping.distribute_rules(group, rules)
      Map.merge(acc, group_rules)
    end)
  end

  defp validate_answer_submission(state, group_id, leader_id, combination) do
    cond do
      state.phase != :solving ->
        {:error, "Game is not in solving phase"}

      not PuzzleEngine.valid_combination?(combination) ->
        {:error, "Invalid combination format"}

      Map.has_key?(state.answers, group_id) ->
        {:error, "Group has already submitted an answer"}

      not is_group_decoder?(state, group_id, leader_id) ->
        {:error, "Only the decoder (team leader) can submit answers"}

      leader_id in state.disconnected_players ->
        {:error, "Disconnected players cannot submit answers"}

      true ->
        :ok
    end
  end

  defp is_group_decoder?(state, group_id, player_id) do
    case Enum.find(state.groups, &(&1.id == group_id)) do
      %{leader_id: ^player_id} ->
        # Leader is always the decoder (assigned in grouping)
        true
      _ ->
        false
    end
  end

  defp all_groups_answered?(state) do
    active_groups = filter_active_groups(state)
    length(Map.keys(state.answers)) >= length(active_groups)
  end

  defp filter_active_groups(state) do
    Enum.filter(state.groups, fn group ->
      # Group is active if it has at least one connected member
      Enum.any?(group.members, fn member ->
        member.indie_id not in state.disconnected_players
      end)
    end)
  end

  defp move_to_scoring(state) do
    scores = calculate_scores(state)
    new_state = %{state |
      phase: :scoring,
      scores: scores
    }

    broadcast_phase_change(state.id, :scoring)
    broadcast_game_event(state.id, {:final_scores, scores, state.secret})

    # Schedule game end
    timer_ref = Process.send_after(self(), :end_game, @scoring_duration)
    new_state = put_in(new_state.phase_timers[:scoring], timer_ref)

    {:noreply, new_state}
  end

  defp calculate_scores(state) do
    Enum.map(state.groups, fn group ->
      answer = Map.get(state.answers, group.id)

      base_score = if answer && answer.is_correct, do: 100, else: 0

      # Bonus points for speed (if answered correctly)
      speed_bonus = if answer && answer.is_correct do
        time_taken = answer.submitted_at - state.start_time
        max(0, 50 - div(time_taken, 1000))  # Up to 50 bonus points
      else
        0
      end

      # Penalty for disconnected members
      connected_members = Enum.count(group.members, fn member ->
        member.indie_id not in state.disconnected_players
      end)

      disconnection_penalty = (length(group.members) - connected_members) * 10

      final_score = max(0, base_score + speed_bonus - disconnection_penalty)

      %{
        group_id: group.id,
        group_emoji: group.emoji,
        members: group.members,
        answer: answer,
        score: final_score,
        breakdown: %{
          base: base_score,
          speed_bonus: speed_bonus,
          disconnection_penalty: disconnection_penalty
        }
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp broadcast_game_event(game_id, event) do
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      @topic_prefix <> game_id,
      {:game_event, event}
    )
  end

  defp broadcast_phase_change(game_id, phase) do
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      @topic_prefix <> game_id,
      {:phase_change, phase}
    )
  end

  defp broadcast_to_lobby(event) do
    Phoenix.PubSub.broadcast(
      IndiesShuffle.PubSub,
      @lobby_topic,
      event
    )
  end
end
