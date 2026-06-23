# General application configuration
import Config

config :data_symphony,
  ecto_repos: [DataSymphony.Repo],
  generators: [timestamp_type: :utc_datetime]

# Track the current environment for runtime branching (e.g. log formatting)
config :data_symphony, :env, config_env()

# Configures the endpoint
config :data_symphony, DataSymphonyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: DataSymphonyWeb.ErrorHTML, json: DataSymphonyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: DataSymphony.PubSub,
  live_view: [signing_salt: "GXH9ELXm"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  data_symphony: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  data_symphony: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
