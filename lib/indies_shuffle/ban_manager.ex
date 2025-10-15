defmodule IndiesShuffle.BanManager do
  @moduledoc """
  GenServer to manage banned users.
  """
  use GenServer

  @table :banned_users

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_state) do
    :ets.new(@table, [:set, :public, :named_table])
    {:ok, %{}}
  end

  # Public API
  def ban_user(indie_id) when is_binary(indie_id) do
    :ets.insert(@table, {indie_id, DateTime.utc_now()})
  end

  def unban_user(indie_id) when is_binary(indie_id) do
    :ets.delete(@table, indie_id)
  end

  def is_banned?(indie_id) when is_binary(indie_id) do
    case :ets.lookup(@table, indie_id) do
      [] -> false
      [{^indie_id, _banned_at}] -> true
    end
  end

  def list_banned_users do
    :ets.tab2list(@table)
    |> Enum.map(fn {indie_id, banned_at} ->
      %{indie_id: indie_id, banned_at: banned_at}
    end)
  end
end
