defmodule IndiesShuffleWeb.Presence do
  use Phoenix.Presence,
    otp_app: :indies_shuffle,
    pubsub_server: IndiesShuffle.PubSub
end
