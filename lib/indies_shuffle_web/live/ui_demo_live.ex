defmodule IndiesShuffleWeb.UiDemoLive do
  use IndiesShuffleWeb, :live_view

  # Embed templates from the ui_demo_live/ directory
  embed_templates "ui_demo_live/*"

  @impl true
  def render(assigns), do: index(assigns)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
