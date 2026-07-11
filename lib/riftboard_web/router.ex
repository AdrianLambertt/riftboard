defmodule RiftboardWeb.Router do
  use RiftboardWeb, :router

  import RiftboardWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RiftboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RiftboardWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", RiftboardWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{RiftboardWeb.UserAuth, :ensure_authenticated}] do
      live "/boards", BoardLive.Index, :index
      live "/boards/new", BoardLive.Index, :new
      live "/boards/:id", BoardLive.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", RiftboardWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:riftboard, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :require_authenticated_user]

      live_dashboard "/dashboard", metrics: RiftboardWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", RiftboardWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{RiftboardWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
    post "/users/guest", UserSessionController, :guest_login
  end

  scope "/", RiftboardWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end
end
