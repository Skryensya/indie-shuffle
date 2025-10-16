defmodule IndiesShuffle.Game.Grouping do
  @moduledoc """
  Handles automatic grouping of players for the combination game.
  Creates groups of 4-6 players with assigned leaders, roles, and group identifiers.
  """

  @min_group_size 2
  @max_group_size 6
  @group_emojis ~w(🦊 🦉 🐢 🐙 🐝 🦄 🐺 🌶️ 🔮 🌊 ⚡ 🎯 🌟 🎨 🎭 🎪)

  # Roles that can be assigned to players
  @roles [:solver, :decoder, :code_holder]

  @doc """
  Returns the list of available roles.
  """
  def roles, do: @roles

  @doc """
  Groups players into teams of 4-6 members with automatic leader assignment and role distribution.
  Returns a list of group maps with id, emoji, leader_id, and members with roles.

  Roles:
  - :decoder - Only player who can submit the final answer (1 per group)
  - :code_holder - Has special information about the secret code (1 per group)
  - :solver - Regular players with clues (remaining members)
  """
  def group_players(players) when is_list(players) and length(players) >= @min_group_size do
    players
    |> Enum.shuffle()
    |> create_balanced_groups()
    |> Enum.with_index()
    |> Enum.map(fn {members, index} ->
      members_with_roles = assign_roles_to_members(members)
      decoder = Enum.find(members_with_roles, fn m -> m.role == :decoder end)

      %{
        id: "group_#{index + 1}",
        emoji: Enum.at(@group_emojis, index),
        leader_id: decoder.indie_id,  # Decoder is always the leader
        members: members_with_roles
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

  # Assigns roles to group members:
  # - First member: :decoder (can submit answers)
  # - Second member: :code_holder (has special code information)
  # - Remaining members: :solver (have puzzle clues)
  defp assign_roles_to_members(members) when is_list(members) do
    members
    |> Enum.shuffle()  # Randomize role assignment
    |> Enum.with_index()
    |> Enum.map(fn {member, index} ->
      role = case index do
        0 -> :decoder
        1 -> :code_holder
        _ -> :solver
      end

      # Add role to member map
      Map.put(member, :role, role)
    end)
  end

  @doc """
  Distributes rules among group members based on their roles:
  - Decoders: No rules (they only submit answers based on team discussion)
  - Code holders: 1-2 special rules about the secret code
  - Solvers: Remaining rules distributed evenly
  """
  def distribute_rules(group, rules) do
    # Separate members by role
    decoder = Enum.find(group.members, fn m -> m.role == :decoder end)
    code_holder = Enum.find(group.members, fn m -> m.role == :code_holder end)
    solvers = Enum.filter(group.members, fn m -> m.role == :solver end)

    # Decoder gets no rules
    decoder_assignment = {get_member_id(decoder), []}

    # Code holder gets first 1-2 rules (special code information)
    code_holder_rules_count = min(2, max(1, div(length(rules), 3)))
    code_holder_rules = Enum.take(rules, code_holder_rules_count)
    code_holder_assignment = {get_member_id(code_holder), code_holder_rules}

    # Distribute remaining rules among solvers
    remaining_rules = Enum.drop(rules, code_holder_rules_count)
    solver_assignments = if length(solvers) > 0 do
      rules_per_solver = max(1, div(length(remaining_rules), length(solvers)))

      solvers
      |> Enum.with_index()
      |> Enum.map(fn {solver, index} ->
        start_index = index * rules_per_solver
        solver_rules = Enum.slice(remaining_rules, start_index, rules_per_solver)

        # Add extra rules to first few solvers if there are remainders
        extra_rules = if index < rem(length(remaining_rules), length(solvers)) do
          extra_index = length(solvers) * rules_per_solver + index
          if extra_index < length(remaining_rules) do
            [Enum.at(remaining_rules, extra_index)]
          else
            []
          end
        else
          []
        end

        {get_member_id(solver), solver_rules ++ extra_rules}
      end)
    else
      []
    end

    # Combine all assignments
    [decoder_assignment, code_holder_assignment | solver_assignments]
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