defmodule IndiesShuffle.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :nickname, :string
    field :session_id, :string
    field :ip_address, :string
    field :user_agent, :string
    field :first_seen_at, :utc_datetime
    field :last_seen_at, :utc_datetime
    field :total_sessions, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:nickname, :session_id, :ip_address, :user_agent, :first_seen_at, :last_seen_at, :total_sessions])
    |> validate_required([:nickname, :session_id, :first_seen_at, :last_seen_at])
    |> validate_length(:nickname, min: 1, max: 50)
    |> unique_constraint(:session_id)
  end
end