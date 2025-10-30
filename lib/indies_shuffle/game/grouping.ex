defmodule IndiesShuffle.Game.Grouping do
  @moduledoc """
  Handles automatic grouping of players.
  Creates groups of 6-8 players with assigned leaders and group identifiers.
  """

  @min_group_size 6
  @max_group_size 8
  @group_emojis ~w(🦊 🦉 🐢 🐙 🐝 🦄 🐺 🌶️ 🔮 🌊 ⚡ 🎯 🌟 🎨 🎭 🎪)

  @doc """
  Groups players into teams of 6-8 members with automatic leader assignment.
  Returns a list of group maps with id, emoji, leader_id, and members.

  Special cases:
  - If total players < 6, creates a single group with everyone
  - If remainder < 6, merges with last group
  """
  def group_players(players) when is_list(players) and length(players) >= 1 do
    players
    |> Enum.shuffle()
    |> create_balanced_groups()
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(@group_emojis, index),
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
      # Less than 6 people: single group
      player_count < @min_group_size ->
        [players]

      # Between 6-8 people: single group
      player_count <= @max_group_size ->
        [players]

      # More than 8 people: create multiple balanced groups
      true ->
        # Calculate optimal number of groups and size per group
        # We want groups between 6-8 people
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

      # Check if all groups will be within 6-8 range
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
  Regroups players while avoiding previous pairings tracked in history.
  Uses a greedy algorithm to create groups where players haven't been together before.
  If impossible to avoid all repeats, minimizes them.
  """
  def regroup_players(players, history) when is_list(players) and length(players) >= 1 do
    # Convert history to MapSet if it's a list
    history_set = if is_list(history), do: MapSet.new(history), else: history

    # Try to create groups avoiding previous pairings
    attempt_regrouping(players, history_set, 0)
  end

  def regroup_players(_players, _history) do
    # No players
    []
  end

  # Attempts to create groups with minimal repetitions
  # max_attempts: number of random shuffles to try
  defp attempt_regrouping(players, history, attempt) when attempt < 10 do
    # Shuffle players to randomize starting point
    shuffled = Enum.shuffle(players)
    groups = build_groups_avoiding_history(shuffled, history, [])

    # Score the grouping (lower is better - fewer repeated pairings)
    score = score_grouping(groups, history)

    if attempt == 0 do
      # First attempt, set as best
      attempt_regrouping(players, history, attempt + 1, groups, score)
    else
      # Try more attempts to find better grouping
      attempt_regrouping(players, history, attempt + 1, groups, score)
    end
  end

  defp attempt_regrouping(_players, _history, _attempt, best_groups, _best_score) do
    # Return best groups found, formatted with IDs and emojis
    best_groups
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(@group_emojis, index),
        leader_id: select_leader(members),
        members: members
      }
    end)
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
    best_groups
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(@group_emojis, index),
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