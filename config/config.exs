# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :tasvir,
  ecto_repos: [Tasvir.Repo]

# Configures the endpoint
config :tasvir, Tasvir.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "FLhxFdWcKUKyFSLF9ukPPDmCPO0PfdnO8NfUmHSmNbkJ58/yJI/kG3Hiw1C2Gzz8",
  render_errors: [view: Tasvir.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Tasvir.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :ex_aws, region: "us-west-2"

config :ex_twilio, account_sid: System.get_env("TWILIO_ACCOUNT_SID"),
                   auth_token:  System.get_env("TWILIO_AUTH_TOKEN"),
                   send_number: "+13345390160"

config :guardian, Guardian,
  allowed_algos: ["HS512"], # optional
  verify_module: Guardian.JWT,  # optional
  issuer: "Tasvir",
  ttl: { 30, :days },
  verify_issuer: true, # optional
  secret_key: System.get_env("ENCRYPTION_KEY"),
  serializer: Tasvir.GuardianSerializer

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
