defmodule DataSymphonyWeb.Router do
  use DataSymphonyWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DataSymphonyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DataSymphonyWeb do
    pipe_through :browser

    live "/", UploadLive, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", DataSymphonyWeb do
  #   pipe_through :api
  # end

  # LiveDashboard is mounted in every environment and gated by AdminAuthPlug:
  # open in dev (`:dev_routes`) and behind HTTP Basic Auth (ADMIN_USERNAME /
  # ADMIN_PASSWORD) on staging and production. This is the F-5 wiring that
  # replaces the former dev-only, compile-gated scope.
  scope "/dev" do
    pipe_through :browser
    pipe_through DataSymphonyWeb.AdminAuthPlug

    live_dashboard "/dashboard", metrics: DataSymphonyWeb.Telemetry
  end
end
