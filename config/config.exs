# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :states_language_live_view, StatesLanguageLiveViewWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Vh2qigJtJsSD83/ZbI0zVOXyk27sKunX/MGPQrrn/vTT6sV4qVgeFu8XPWaORFQD",
  render_errors: [view: StatesLanguageLiveViewWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: StatesLanguageLiveView.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "ArI5zbm+CvsSufjTffiP/7OEDwDF5zAQ"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
