defmodule IndiesShuffle.Repo do
  use Ecto.Repo,
    otp_app: :indies_shuffle,
    adapter: Ecto.Adapters.SQLite3
end
