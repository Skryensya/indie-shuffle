defmodule IndiesShuffleWeb.PageController do
  use IndiesShuffleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
