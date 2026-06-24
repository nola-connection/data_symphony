import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :data_symphony, DataSymphony.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "data_symphony_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :data_symphony, DataSymphonyWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "CtVBB100pEpI34y5YUUcxb9ult8tNwOCdhzCL5YEZwWEJoCvlhgsgHOHcVdyXoe9",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Structured logging with metadata for testing
config :logger, :console,
  format: {DataSymphony.Logger.StructuredFormatter, :format},
  metadata: [:request_id, :user_id, :job_id, :duration_ms]

# Enable dev routes for testing
config :data_symphony, dev_routes: true

# Default blob storage root for tests; individual tests override this with an
# isolated temporary directory.
config :data_symphony, DataSymphony.BlobStorage.Filesystem,
  root: Path.expand("../tmp/blob_storage/test", __DIR__)

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
