defmodule IndiesShuffle.Game.Grouping do
  @moduledoc """
  Handles automatic grouping of players.
  Creates groups of 6-8 players with assigned leaders and group identifiers.
  """

  @min_group_size 1
  @max_group_size 8
  @group_emojis ["🔥", "⚡", "🌟", "🚀", "🎯", "💎", "👑", "🎸", "🎮", "⭐", "💫", "🎲", "🎰", "🏆", "🍕", "🌮", "🍦", "⚽", "🎪", "🎭", "🎨", "🎤", "🎧", "🎬", "📱", "💻", "🎹", "🥁", "🎺", "🎻", "🏀", "⚾", "🏈", "🎾"]

  @doc """
  Groups players into teams of 1-8 members with automatic leader assignment.
  Returns a list of group maps with id, emoji, leader_id, and members.

  Special cases:
  - If total players < 1, returns empty list
  - If remainder < 1, merges with last group
  """
  def group_players(players) when is_list(players) and length(players) >= 1 do
    groups = players
    |> Enum.shuffle()
    |> create_balanced_groups()

    # Shuffle emojis and take as many as needed (without repetition)
    shuffled_emojis = Enum.shuffle(@group_emojis)

    groups
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(shuffled_emojis, index),
        leader_id: select_leader(members),
        members: members
      }
    end)
  end

  def group_players(_players) do
    # No players
    []
  end

  defp create_balanced_groups(players) do
    player_count = length(players)

    cond do
      # Less than 1 people: no groups
      player_count < @min_group_size ->
        []

      # Between 1-8 people: single group
      player_count <= @max_group_size ->
        [players]

      # More than 8 people: create multiple balanced groups
      true ->
        # Calculate optimal number of groups and size per group
        # We want groups between 1-8 people
        num_groups = calculate_optimal_group_count(player_count)
        base_size = div(player_count, num_groups)
        extra_players = rem(player_count, num_groups)

        # Distribute players across groups
        # First 'extra_players' groups get (base_size + 1), rest get base_size
        {groups, _} = Enum.reduce(0..(num_groups - 1), {[], players}, fn index, {acc_groups, remaining} ->
          group_size = if index < extra_players, do: base_size + 1, else: base_size
          {group, rest} = Enum.split(remaining, group_size)
          {acc_groups ++ [group], rest}
        end)

        groups
    end
  end

  # Calculates optimal number of groups to keep sizes between 6-8 with even distribution
  defp calculate_optimal_group_count(player_count) do
    # Try different group counts starting from the minimum possible
    # We want groups as balanced as possible
    min_possible_groups = div(player_count, @max_group_size)
    max_possible_groups = div(player_count, @min_group_size) + 1

    # Find the best group count that keeps all groups between 6-8
    Enum.find(min_possible_groups..max_possible_groups, fn num_groups ->
      base_size = div(player_count, num_groups)
      remainder = rem(player_count, num_groups)

      # Smallest group will have base_size
      # Largest group will have base_size + 1 (if there's a remainder)
      min_group_size = base_size
      max_group_size = if remainder > 0, do: base_size + 1, else: base_size

      # Check if all groups will be within 1-8 range
      min_group_size >= @min_group_size and max_group_size <= @max_group_size
    end) ||
    # Fallback: divide by max size and add 1
    max(1, div(player_count, @max_group_size) + 1)
  end

  defp redistribute_players(groups, []), do: groups
  defp redistribute_players(groups, remaining_players) do
    # Add one player to each group until all are distributed
    groups
    |> Enum.with_index()
    |> Enum.map(fn {group, index} ->
      case Enum.at(remaining_players, index) do
        nil -> group
        player -> [player | group]
      end
    end)
  end

  defp select_leader(members) when is_list(members) and length(members) > 0 do
    member = Enum.random(members)
    case member do
      %{indie_id: indie_id} -> indie_id
      %{id: id} -> id
      _ -> member
    end
  end

  @doc """
  Distributes rules among group members, ensuring each player gets 1-2 rules.
  """
  def distribute_rules(group, rules) do
    member_count = length(group.members)
    rules_per_member = max(1, div(length(rules), member_count))

    group.members
    |> Enum.with_index()
    |> Enum.map(fn {member, index} ->
      start_index = index * rules_per_member
      member_rules = Enum.slice(rules, start_index, rules_per_member)

      # Add extra rules to first few members if there are remainders
      extra_rules = if index < rem(length(rules), member_count) do
        [Enum.at(rules, member_count * rules_per_member + index)]
      else
        []
      end

      {get_member_id(member), member_rules ++ extra_rules}
    end)
    |> Map.new()
  end

  defp get_member_id(%{indie_id: indie_id}), do: indie_id
  defp get_member_id(%{id: id}), do: id
  defp get_member_id(member), do: member

  @doc """
  Returns minimum and maximum group sizes.
  """
  def group_size_limits, do: {@min_group_size, @max_group_size}

  @doc """
  Checks if the number of players is sufficient for grouping.
  With new rules, we accept any number of players (even < 6 forms one group).
  """
  def sufficient_players?(player_count) when is_integer(player_count) do
    player_count >= 1
  end

  @doc """
  Regroups players ensuring each player goes to a DIFFERENT group than their previous one.
  Also avoids previous pairings when possible.
  Uses an algorithm that guarantees homogeneous distribution with rotation.
  """
  def regroup_players(players, history, previous_groups \\ []) when is_list(players) and length(players) >= 1 do
    # Convert history to MapSet if it's a list
    history_set = if is_list(history), do: MapSet.new(history), else: history

    # Build a map of player_id -> previous_group_id
    previous_group_map = build_previous_group_map(previous_groups)

    # Try to create groups with rotation and avoiding previous pairings
    attempt_regrouping_with_rotation(players, history_set, previous_group_map, 0)
  end

  def regroup_players(_players, _history, _previous_groups) do
    # No players
    []
  end

  # Build a map of player_id -> group_id from previous groups
  defp build_previous_group_map(groups) when is_list(groups) do
    groups
    |> Enum.reduce(%{}, fn group, acc ->
      group_id = Map.get(group, :id)
      members = Map.get(group, :members, [])

      Enum.reduce(members, acc, fn member, inner_acc ->
        player_id = get_member_id(member)
        Map.put(inner_acc, player_id, group_id)
      end)
    end)
  end

  defp build_previous_group_map(_), do: %{}

  # Attempts to create groups with rotation ensuring no player stays in same group
  defp attempt_regrouping_with_rotation(players, history, previous_group_map, 0) do
    # First attempt using rotation algorithm
    groups = create_rotated_groups(players, previous_group_map)
    score = score_grouping(groups, history)
    attempt_regrouping_with_rotation(players, history, previous_group_map, 1, groups, score)
  end

  defp attempt_regrouping_with_rotation(players, history, previous_group_map, attempt) when attempt < 10 do
    # Try more attempts with shuffling to find better grouping
    groups = create_rotated_groups(players, previous_group_map)
    score = score_grouping(groups, history)
    attempt_regrouping_with_rotation(players, history, previous_group_map, attempt + 1, groups, score)
  end

  defp attempt_regrouping_with_rotation(players, _history, _previous_group_map, attempt) when attempt >= 10 do
    # Max attempts reached, fallback to simple grouping
    group_players(players)
  end

  defp attempt_regrouping_with_rotation(players, history, previous_group_map, attempt, best_groups, best_score) when attempt < 10 do
    groups = create_rotated_groups(players, previous_group_map)
    score = score_grouping(groups, history)

    if score < best_score do
      # Found better grouping
      attempt_regrouping_with_rotation(players, history, previous_group_map, attempt + 1, groups, score)
    else
      # Keep previous best
      attempt_regrouping_with_rotation(players, history, previous_group_map, attempt + 1, best_groups, best_score)
    end
  end

  defp attempt_regrouping_with_rotation(_players, _history, _previous_group_map, _attempt, best_groups, _best_score) do
    # Max attempts reached, return best found with formatted groups
    # Shuffle emojis to assign randomly without repetition
    shuffled_emojis = Enum.shuffle(@group_emojis)

    best_groups
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(shuffled_emojis, index),
        leader_id: select_leader(members),
        members: members
      }
    end)
  end

  # Creates balanced groups ensuring each player goes to a different group than before
  defp create_rotated_groups(players, previous_group_map) do
    player_count = length(players)

    cond do
      player_count < @min_group_size ->
        []

      player_count <= @max_group_size ->
        [players]

      true ->
        # Calculate optimal number of groups
        num_groups = calculate_optimal_group_count(player_count)
        base_size = div(player_count, num_groups)
        extra_players = rem(player_count, num_groups)

        # Separate players by their previous group
        players_by_prev_group = Enum.group_by(players, fn player ->
          player_id = get_member_id(player)
          Map.get(previous_group_map, player_id, :no_group)
        end)

        # Create a rotation strategy: for each previous group, distribute its members
        # to different new groups using a round-robin approach with offset
        distributed_groups = distribute_with_rotation(
          players_by_prev_group,
          num_groups,
          base_size,
          extra_players
        )

        # Balance groups if needed
        balance_group_sizes(distributed_groups, base_size, extra_players)
    end
  end

  # Distributes players from previous groups using rotation to ensure diversity
  defp distribute_with_rotation(players_by_prev_group, num_groups, base_size, extra_players) do
    # Initialize empty groups
    initial_groups = List.duplicate([], num_groups)

    # For each previous group, distribute its players across new groups with an offset
    {final_groups, _offset} = players_by_prev_group
    |> Enum.reduce({initial_groups, 0}, fn {_prev_group_id, group_players}, {acc_groups, offset} ->
      # Shuffle players from this previous group
      shuffled = Enum.shuffle(group_players)

      # Distribute them across new groups with rotation and offset
      new_groups = shuffled
      |> Enum.with_index()
      |> Enum.reduce(acc_groups, fn {player, idx}, groups ->
        # Use offset to ensure players don't go to same relative position
        target_group_idx = rem(idx + offset, num_groups)
        List.update_at(groups, target_group_idx, fn group -> [player | group] end)
      end)

      # Increment offset for next previous group
      {new_groups, offset + 1}
    end)

    final_groups
  end

  # Balances group sizes to match target distribution
  defp balance_group_sizes(groups, base_size, extra_players) do
    # Calculate target size for each group
    groups_with_targets = groups
    |> Enum.with_index()
    |> Enum.map(fn {group, idx} ->
      target = if idx < extra_players, do: base_size + 1, else: base_size
      {group, target}
    end)

    # Separate groups into those that are too large and too small
    {oversized, undersized} = Enum.split_with(groups_with_targets, fn {group, target} ->
      length(group) > target
    end)

    # Move players from oversized to undersized groups
    balanced = redistribute_between_groups(oversized, undersized)

    # Return just the groups (without targets)
    Enum.map(balanced, fn {group, _target} -> group end)
  end

  # Redistributes players from oversized to undersized groups
  defp redistribute_between_groups(oversized, undersized) do
    # For each oversized group, move excess players to undersized groups
    {final_oversized, final_undersized} = Enum.reduce(oversized, {[], undersized}, fn {group, target}, {acc_over, acc_under} ->
      excess = length(group) - target

      if excess > 0 do
        # Take excess players
        {to_move, remaining} = Enum.split(group, excess)

        # Distribute to undersized groups
        new_undersized = distribute_players_to_groups(to_move, acc_under)

        {[{remaining, target} | acc_over], new_undersized}
      else
        {[{group, target} | acc_over], acc_under}
      end
    end)

    final_oversized ++ final_undersized
  end

  # Distributes players to groups that need them
  defp distribute_players_to_groups([], groups), do: groups
  defp distribute_players_to_groups(players, groups) do
    # Sort groups by how many more players they need
    sorted_groups = Enum.sort_by(groups, fn {group, target} ->
      target - length(group)
    end, :desc)

    # Distribute one player at a time to groups that need them most
    Enum.reduce(players, sorted_groups, fn player, current_groups ->
      # Find first group that needs a player
      case Enum.find_index(current_groups, fn {group, target} -> length(group) < target end) do
        nil ->
          # No group needs players, add to first group
          [{first_group, first_target} | rest] = current_groups
          [{[player | first_group], first_target} | rest]

        idx ->
          # Add to group that needs it
          List.update_at(current_groups, idx, fn {group, target} ->
            {[player | group], target}
          end)
      end
    end)
  end

  # Original attempt_regrouping functions kept for backward compatibility
  # (These are now used as fallback only)
  defp attempt_regrouping(players, history, 0) do
    # First attempt, set as best
    shuffled = Enum.shuffle(players)
    groups = build_groups_avoiding_history(shuffled, history, [])
    score = score_grouping(groups, history)
    attempt_regrouping(players, history, 1, groups, score)
  end

  defp attempt_regrouping(players, history, attempt) when attempt < 10 do
    # Try more attempts to find better grouping
    shuffled = Enum.shuffle(players)
    groups = build_groups_avoiding_history(shuffled, history, [])
    score = score_grouping(groups, history)
    # This will call the 5-argument version
    attempt_regrouping(players, history, attempt + 1, groups, score)
  end

  defp attempt_regrouping(players, _history, attempt) when attempt >= 10 do
    # Max attempts reached without best groups, fallback to simple grouping
    group_players(players)
  end

  defp attempt_regrouping(players, history, attempt, best_groups, best_score) when attempt < 10 do
    shuffled = Enum.shuffle(players)
    groups = build_groups_avoiding_history(shuffled, history, [])
    score = score_grouping(groups, history)

    if score < best_score do
      # Found better grouping
      attempt_regrouping(players, history, attempt + 1, groups, score)
    else
      # Keep previous best
      attempt_regrouping(players, history, attempt + 1, best_groups, best_score)
    end
  end

  defp attempt_regrouping(_players, _history, _attempt, best_groups, _best_score) do
    # Max attempts reached, return best found
    # Shuffle emojis to assign randomly without repetition
    shuffled_emojis = Enum.shuffle(@group_emojis)

    best_groups
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(shuffled_emojis, index),
        leader_id: select_leader(members),
        members: members
      }
    end)
  end

  # Builds groups using greedy approach, trying to avoid history with even distribution
  defp build_groups_avoiding_history([], _history, groups), do: Enum.reverse(groups)

  defp build_groups_avoiding_history(players, history, groups) do
    player_count = length(players)

    # If less than 6 players remaining and we already have groups, merge with last group
    if player_count < @min_group_size and groups != [] do
      [last_group | rest] = groups
      merged_group = last_group ++ players
      Enum.reverse([merged_group | rest])
    else
      # Calculate optimal group size for even distribution
      num_groups_to_create = calculate_optimal_group_count(player_count)
      current_group_index = length(groups)
      groups_remaining = num_groups_to_create - current_group_index

      # Calculate target size for this group to ensure even distribution
      target_size = if groups_remaining > 0 do
        # Distribute remaining players evenly across remaining groups
        base = div(player_count, groups_remaining)
        extra = rem(player_count, groups_remaining)
        # First 'extra' groups get one more player
        if current_group_index < extra, do: base + 1, else: base
      else
        # Fallback to balanced size
        div(player_count, max(1, div(player_count, @max_group_size)))
      end

      # Ensure target_size is within bounds
      target_size = max(@min_group_size, min(@max_group_size, target_size))

      # Build one group at a time
      {group, remaining} = build_single_group(players, history, target_size, [])

      # Check if remaining players are too few
      remaining_count = length(remaining)

      if remaining_count > 0 and remaining_count < @min_group_size do
        # Merge remaining with current group
        merged_group = group ++ remaining
        Enum.reverse([merged_group | groups])
      else
        # Continue building groups
        build_groups_avoiding_history(remaining, history, [group | groups])
      end
    end
  end

  # Builds a single group trying to avoid players who've been together before
  defp build_single_group([], _history, _target_size, group), do: {Enum.reverse(group), []}

  defp build_single_group(players, _history, target_size, group) when length(group) >= target_size do
    # Group is full
    {Enum.reverse(group), players}
  end

  defp build_single_group([player | rest], history, target_size, group) do
    # Check if this player has been with anyone in current group
    player_id = get_member_id(player)

    conflicts = Enum.count(group, fn existing ->
      existing_id = get_member_id(existing)
      pair = if player_id < existing_id, do: {player_id, existing_id}, else: {existing_id, player_id}
      MapSet.member?(history, pair)
    end)

    if conflicts == 0 or length(group) == 0 do
      # No conflicts or first member, add to group
      build_single_group(rest, history, target_size, [player | group])
    else
      # Has conflicts, try to place later
      {final_group, remaining} = build_single_group(rest, history, target_size, group)
      {final_group, [player | remaining]}
    end
  end

  # Scores a grouping by counting repeated pairings (lower is better)
  defp score_grouping(groups, history) do
    groups
    |> Enum.map(fn group ->
      member_ids = Enum.map(group, fn m -> get_member_id(m) end)

      # Count how many pairs in this group are in history
      pairs = for i <- 0..(length(member_ids) - 1),
                  j <- (i + 1)..(length(member_ids) - 1) do
        p1 = Enum.at(member_ids, i)
        p2 = Enum.at(member_ids, j)
        pair = if p1 < p2, do: {p1, p2}, else: {p2, p1}

        if MapSet.member?(history, pair), do: 1, else: 0
      end

      Enum.sum(pairs)
    end)
    |> Enum.sum()
  end
end
