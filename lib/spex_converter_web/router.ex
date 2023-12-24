defmodule SpexConverterWeb.Router do
  use SpexConverterWeb, :router
  import Plug.Conn

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SpexConverterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: SpexConverterWeb.ApiSpec
  end

  pipeline :authentication do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: SpexConverterWeb.ApiSpec
    plug :validate_api_key
  end

  scope "/" do
    pipe_through :api

    get "/docs/api_spec", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/" do
    get "/docs/api", OpenApiSpex.Plug.SwaggerUI, path: "/docs/api_spec"
  end

  scope "/v1", SpexConverterWeb do
    pipe_through :authentication

    post "/convert", ConverterController, :convert
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:spex_converter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SpexConverterWeb.Telemetry
    end
  end

  defp validate_api_key(conn, _opts) do
    with ["Bearer " <> key] <- get_req_header(conn, "authorization"),
         true <- validate_api_key?(key) do
      conn
    else
      _ ->
        conn
        |> send_resp(:unauthorized, "Invalid API Key")
        |> halt()
    end
  end

  defp validate_api_key?(key), do: key == api_key()

  defp api_key, do: Application.get_env(:spex_converter, :auth_api_key)
end
