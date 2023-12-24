defmodule SpexConverterWeb.ConverterController do
  use SpexConverterWeb, :controller
  use SpexConverterWeb.ApiSpec

  alias OpenApiSpex.Schema

  operation :convert,
    operation_id: "convert",
    summary: "Convert an OpenAPI spec to its corresponding OpenApiSpex representation",
    parameters: [],
    request_body: %OpenApiSpex.RequestBody{
      description: "payload",
      required: true,
      content: %{
        "application/json" => %OpenApiSpex.MediaType{
          schema: %Schema{
            oneOf: [
              %Schema{
                type: :object,
                required: [:url],
                properties: %{
                  url: %Schema{
                    type: :string
                  }
                }
              },
              %Schema{
                type: :object,
                required: [:content],
                properties: %{
                  content: %Schema{
                    type: :string
                  }
                }
              }
            ]
          }
        }
      }
    },
    responses: [
      ok:
        {"Success", "text/plain",
         %Schema{
           type: :string,
           description: "The converted OpenApiSpex representation of the OpenAPI spec"
         }},
      unprocessable_entity: OpenApiSpex.JsonErrorResponse.response()
    ]

  def convert(conn, params) do
    # TODO: error handling of any type. We could check for json or yaml, validate specs, and provide usable errors.
    # This is specifically just to test the flame behavior
    usable_content =
      if is_binary(params["url"]) do
        Req.get!(params["url"]).body()
      else
        params["content"]
      end

    # We use FLAME to run the conversion in a separate process to avoid potential atom DOS
    # @see https://github.com/open-api-spex/open_api_spex?tab=readme-ov-file#importing-an-existing-schema-file
    output =
      FLAME.call(SpexConverter.ConvertSpec, fn ->
        usable_content
        |> OpenApiSpex.OpenApi.Decode.decode()
        |> inspect(limit: :infinity)
        |> sanitize_and_format()
      end)

    text(conn, output)
  end

  defp sanitize_and_format(contents) do
    contents
    |> String.replace("%OpenApiSpex.Schema%{", "%OpenApiSpex.Schema{")
    |> elixir_format()
  end

  defp elixir_format(content, formatter_opts \\ []) do
    case Code.format_string!(content, formatter_opts) do
      [] -> ""
      formatted_content -> IO.iodata_to_binary([formatted_content, ?\n])
    end
  end
end
