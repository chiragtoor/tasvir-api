use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tasvir, Tasvir.Endpoint,
  http: [port: 4001],
  server: false,
  bucket: "tasvir-test"

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :tasvir, Tasvir.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "tasvir_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox
