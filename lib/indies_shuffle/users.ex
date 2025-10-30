defmodule IndiesShuffle.Users do
  @moduledoc """
  The Users context for tracking unique users and their sessions.
  """

  import Ecto.Query, warn: false
  alias IndiesShuffle.Repo
  alias IndiesShuffle.Users.User

  @doc """
  Logs a user entry. If the user exists (by session_id), updates last_seen_at
  and increments total_sessions. If new, creates a new user record.
  """
  def log_user_entry(attrs) do
    session_id = Map.get(attrs, :session_id) || Map.get(attrs, "session_id")
    
    case get_user_by_session_id(session_id) do
      nil ->
        create_user(attrs)
      existing_user ->
        update_user_last_seen(existing_user, attrs)
    end
  end

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Returns users ordered by first_seen_at desc (newest first).
  """
  def list_users_recent_first do
    User
    |> order_by(desc: :first_seen_at)
    |> Repo.all()
  end

  @doc """
  Gets a single user by ID.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by session_id.
  """
  def get_user_by_session_id(session_id) do
    Repo.get_by(User, session_id: session_id)
  end

  @doc """
  Creates a user.
  """
  def create_user(attrs \\ %{}) do
    attrs_with_timestamps = 
      attrs
      |> Map.put_new(:first_seen_at, DateTime.utc_now())
      |> Map.put_new(:last_seen_at, DateTime.utc_now())

    %User{}
    |> User.changeset(attrs_with_timestamps)
    |> Repo.insert()
  end

  @doc """
  Updates a user's last_seen_at and increments total_sessions.
  """
  def update_user_last_seen(user, attrs \\ %{}) do
    update_attrs = 
      attrs
      |> Map.put(:last_seen_at, DateTime.utc_now())
      |> Map.put(:total_sessions, user.total_sessions + 1)

    user
    |> User.changeset(update_attrs)
    |> Repo.update()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  @doc """
  Returns statistics about users.
  """
  def get_user_stats do
    total_users = Repo.aggregate(User, :count, :id)
    
    recent_users = 
      User
      |> where([u], u.first_seen_at >= ago(24, "hour"))
      |> Repo.aggregate(:count, :id)

    %{
      total_users: total_users,
      recent_users_24h: recent_users
    }
  end
end