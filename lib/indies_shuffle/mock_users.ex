defmodule IndiesShuffle.MockUsers do
  @moduledoc """
  Manages mock users for testing purposes.
  """
  use GenServer
  alias IndiesShuffleWeb.Presence

  @topic "lobby:presence"

  # === Public API ===

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Creates N mock users and tracks them in Presence.
  """
  def create_mock_users(count) when count > 0 and count <= 1000 do
    GenServer.call(__MODULE__, {:create_mock_users, count})
  end

  @doc """
  Removes all mock users from Presence.
  """
  def clear_mock_users do
    GenServer.call(__MODULE__, :clear_mock_users)
  end

  @doc """
  Returns the list of currently active mock user PIDs.
  """
  def list_mock_users do
    GenServer.call(__MODULE__, :list_mock_users)
  end

  # === GenServer Callbacks ===

  @impl true
  def init(_) do
    {:ok, %{mock_processes: []}}
  end

  @impl true
  def handle_call({:create_mock_users, count}, _from, state) do
    IO.puts("🤖 Creating #{count} mock users...")

    # Create processes for each mock user
    mock_processes = Enum.map(1..count, fn i ->
      spawn_link(fn -> mock_user_process(i) end)
    end)

    # Give processes a moment to register
    Process.sleep(100)

    new_state = %{state | mock_processes: state.mock_processes ++ mock_processes}

    IO.puts("✅ Created #{count} mock users (total: #{length(new_state.mock_processes)})")
    {:reply, {:ok, count}, new_state}
  end

  @impl true
  def handle_call(:clear_mock_users, _from, state) do
    IO.puts("🧹 Clearing all mock users...")

    # Kill all mock user processes
    Enum.each(state.mock_processes, fn pid ->
      Process.exit(pid, :kill)
    end)

    IO.puts("✅ Cleared #{length(state.mock_processes)} mock users")
    {:reply, {:ok, length(state.mock_processes)}, %{state | mock_processes: []}}
  end

  @impl true
  def handle_call(:list_mock_users, _from, state) do
    {:reply, state.mock_processes, state}
  end

  # === Private Functions ===

  defp mock_user_process(index) do
    # Generate unique indie_id and token
    indie_id = "mock_#{System.unique_integer([:positive])}"
    token = "mock_token_#{indie_id}"
    name = generate_mock_name(index)

    IO.puts("🤖 Mock user #{index} starting: #{name} (#{indie_id})")

    # Track presence
    {:ok, _} = Presence.track(self(), @topic, token, %{
      indie_id: indie_id,
      name: name,
      pid: self(),
      joined_at: System.system_time(:second),
      is_mock: true
    })

    # Try to join active game if one exists
    try_join_active_game(indie_id, name)

    # Keep the process alive
    mock_user_loop()
  end

  defp try_join_active_game(indie_id, name) do
    # Check if there's an active game
    case Registry.select(IndiesShuffle.Registry, [{{:_, :_, :_}, [], [:"$_"]}])
         |> Enum.find(fn {{:game, _game_id}, _pid, _value} -> true; _ -> false end) do
      {{:game, game_id}, _pid, _value} ->
        IO.puts("🎮 Mock user #{name} joining active game #{game_id}")

        player = %{
          id: indie_id,
          indie_id: indie_id,
          name: name
        }

        case IndiesShuffle.Game.GameServer.assign_player_to_group(game_id, player) do
          {:ok, assigned_group} ->
            IO.puts("✅ Mock user #{name} assigned to group #{assigned_group.id}")
          _ ->
            IO.puts("⚠️ Mock user #{name} failed to join game")
        end

      _ ->
        # No active game, that's fine
        :ok
    end
  end

  defp mock_user_loop do
    receive do
      :stop -> :ok
    after
      :infinity -> :ok
    end
  end

  defp generate_mock_name(index) do
    # Lista de nombres reales comunes
    names = [
      "Sofia", "Emma", "Isabella", "Mia", "Camila",
      "Valentina", "Martina", "Victoria", "Catalina", "Elena",
      "Ana", "Julia", "Paula", "Daniela", "Carolina",
      "Maria", "Lucia", "Andrea", "Sara", "Alejandra",
      "Diego", "Santiago", "Mateo", "Sebastian", "Nicolas",
      "Andres", "Juan", "Carlos", "Luis", "Miguel",
      "Daniel", "Gabriel", "David", "Pablo", "Javier",
      "Fernando", "Ricardo", "Roberto", "Antonio", "Manuel",
      "Pedro", "Jorge", "Alberto", "Raul", "Mario",
      "Lucas", "Martin", "Alejandro", "Francisco", "Eduardo",
      "Valeria", "Natalia", "Gabriela", "Laura", "Monica",
      "Patricia", "Isabel", "Rosa", "Beatriz", "Carmen",
      "Adriana", "Diana", "Marcela", "Claudia", "Sandra",
      "Liliana", "Gloria", "Teresa", "Silvia", "Angela",
      "Felipe", "Tomas", "Ignacio", "Rafael", "Emilio",
      "Adrian", "Oscar", "Sergio", "Marcos", "Ivan",
      "Cristian", "Rodrigo", "Hector", "Alvaro", "Victor",
      "Leonardo", "Mauricio", "Esteban", "Guillermo", "Arturo",
      "Joaquin", "Ramon", "Cesar", "Hugo", "Armando",
      "Renata", "Luna", "Alma", "Clara", "Lola",
      "Iris", "Nina", "Maya", "Vera", "Gala",
      "Nora", "Dora", "Ada", "Eva", "Luz",
      "Paz", "Sol", "Mar", "Abril", "Jade",
      "Liam", "Noah", "Oliver", "Ethan", "Leo",
      "Alex", "Max", "Sam", "Jack", "Owen"
    ]

    # Seleccionar nombre basado en el índice
    name = Enum.at(names, rem(index - 1, length(names)))

    # Si hay más de 120 usuarios, agregar un número al final
    if index > length(names) do
      "#{name}#{div(index - 1, length(names)) + 1}"
    else
      name
    end
  end
end
