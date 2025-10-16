defmodule IndiesShuffleWeb.Router do
  use IndiesShuffleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IndiesShuffleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", IndiesShuffleWeb do
    pipe_through :browser

    live_session :default do
      live "/", LobbyLive, :index
      live "/ui-demo", UiDemoLive, :index
    end

    live_session :admin,
      layout: {IndiesShuffleWeb.Layouts, :admin} do
      live "/admin", AdminLive, :index
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", IndiesShuffleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:indies_shuffle, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: IndiesShuffleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
