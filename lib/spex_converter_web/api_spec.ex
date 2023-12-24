defmodule SpexConverterWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  alias SpexConverterWeb.Router
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @impl OpenApi
  def spec do
    OpenApiSpex.resolve_schema_modules(%OpenApi{
      servers: [
        %Server{url: "http://localhost:4000", description: "Local server"},
        %Server{url: "https://spex-converter.fly.dev", description: "Fly server"}

      ],
      info: %Info{
        title: "SpexConverter Service",
        version: to_string(Application.spec(:spex_converter, :vsn)),
        description: """
          Converting things for fun!
        """
      },
      paths: Paths.from_router(Router),
      components: %Components{
        securitySchemes: %{
          "authorization" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "The API key"
          }
        }
      },
      security: [
        %{
          "authorization" => []
        }
      ]
    })
  end

  defmacro __using__(opts \\ []) do
    quote do
      use OpenApiSpex.ControllerSpecs

      alias OpenApiSpex.Operation

      plug OpenApiSpex.Plug.CastAndValidate,
           [json_render_error_v2: true, replace_params: false] ++ unquote(opts)

      @doc """
      Returns the private body params data that open api spex has stored on the conn.

      We have to do this because dialyzer does not enjoy us passing random fields
      on the Plug.Conn.
      """
      def body_params(conn) do
        conn.private.open_api_spex.body_params
      end

      def spex_params(conn) do
        spex_body_params =
          get_in(conn, [Access.key(:private), :open_api_spex, Access.key(:body_params, %{})])

        spex_query_params =
          get_in(conn, [Access.key(:private), :open_api_spex, Access.key(:params, %{})])

        spex_params = Map.merge(%{body_params: spex_body_params}, spex_query_params)

        # Merging params and spex_params directly into conn.params
        updated_conn = %{conn | params: Map.merge(conn.params, spex_params)}

        updated_conn
      end
    end
  end
end
