defmodule IndiesShuffle.Game.Grouping do
  @moduledoc """
  Handles automatic grouping of players for the combination game.
  Creates groups of 4-6 players with assigned leaders and group identifiers.
  """

  @min_group_size 4
  @max_group_size 6
  @group_emojis ~w(🦊 🦉 🐢 🐙 🐝 🦄 🐺 🌶️ 🔮 🌊 ⚡ 🎯 🌟 🎨 🎭 🎪)

  @doc """
  Groups players into teams of 4-6 members with automatic leader assignment.
  Returns a list of group maps with id, emoji, leader_id, and members.
  """
  def group_players(players) when is_list(players) and length(players) >= @min_group_size do
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

  def group_players(players) when is_list(players) do
    # Not enough players for proper grouping
    []
  end

  defp create_balanced_groups(players) do
    player_count = length(players)
    
    cond do
      player_count < @min_group_size ->
        []
      
      player_count <= @max_group_size ->
        # Single group
        [players]
      
      true ->
        # Multiple groups - balance the sizes
        ideal_groups = div(player_count, @max_group_size)
        remainder = rem(player_count, @max_group_size)
        
        if remainder >= @min_group_size do
          # Can make an additional group with remainder
          groups = Enum.chunk_every(players, @max_group_size) |> Enum.take(ideal_groups)
          remaining_players = Enum.drop(players, ideal_groups * @max_group_size)
          groups ++ [remaining_players]
        else
          # Redistribute remainder across existing groups
          base_groups = Enum.chunk_every(players, @max_group_size) |> Enum.take(ideal_groups)
          remaining_players = Enum.drop(players, ideal_groups * @max_group_size)
          
          redistribute_players(base_groups, remaining_players)
        end
    end
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
  """
  def sufficient_players?(player_count) when is_integer(player_count) do
    player_count >= @min_group_size
  end
end