defmodule IndiesShuffle.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :nickname, :string, null: false
      add :session_id, :string, null: false
      add :ip_address, :string
      add :user_agent, :string
      add :first_seen_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime, null: false
      add :total_sessions, :integer, default: 1

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:session_id])
    create index(:users, [:nickname])
    create index(:users, [:ip_address])
    create index(:users, [:first_seen_at])
  end
end
