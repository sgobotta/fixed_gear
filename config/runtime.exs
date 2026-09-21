import Config

require Logger

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/fixed_gear start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :fixed_gear, FixedGearWeb.Endpoint, server: true
end

config :fixed_gear, stage: System.fetch_env!("STAGE")

port = String.to_integer(System.get_env("PORT", "4000"))

config :fixed_gear, FixedGearWeb.Endpoint, http: [port: port]

if config_env() == :dev do
  ip =
    case System.get_env("APP_HOST") do
      "0.0.0.0" -> {0, 0, 0, 0}
      _ -> {127, 0, 0, 1}
    end

  config :fixed_gear, FixedGearWeb.Endpoint, http: [ip: ip, port: port]
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :fixed_gear, FixedGearWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$",
        # Gettext translations
        ~r"priv/gettext/.*\.po$",
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/fixed_gear_web/router\.ex$",
        ~r"lib/fixed_gear_web/(controllers|live|components)/.*\.(ex|heex)$"
      ]
    ]
end

if config_env() == :prod do
  maybe_ipv6 =
    if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :fixed_gear, FixedGear.Repo,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  host = System.fetch_env!("APP_HOST")
  port = String.to_integer(System.get_env("PORT", "443"))

  case System.get_env("STAGE") do
    stage when stage in ["local", "dev", "staging", "prod"] ->
      :ok =
        Logger.warning(
          "Ignoring variable DATABASE_URL as Postgrex connection protocol, proceding with default tcp connection."
        )

      config(:fixed_gear, FixedGear.Repo,
        database: System.get_env("DB_DATABASE"),
        username: System.fetch_env!("DB_USERNAME"),
        password: System.fetch_env!("DB_PASSWORD"),
        hostname: System.fetch_env!("DB_HOSTNAME")
      )

      config :fixed_gear, FixedGearWeb.Endpoint,
        http: [
          ip: {0, 0, 0, 0, 0, 0, 0, 0},
          port: port
        ],
        url: [host: host, port: 80]

    _stage ->
      database_url =
        System.get_env("DATABASE_URL") ||
          raise """
          environment variable DATABASE_URL is missing.
          For example: ecto://USER:PASS@HOST/DATABASE
          """

      :ok = Logger.info("Using DATABASE_URL as Postgrex connection protocol.")

      config :fixed_gear, FixedGear.Repo,
        ssl: true,
        url: database_url,
        database: Enum.at(String.split(database_url, "/"), -1)

      config :fixed_gear, FixedGearWeb.Endpoint,
        http: [
          ip: {0, 0, 0, 0, 0, 0, 0, 0},
          port: port
        ],
        url: [scheme: "https", host: host, port: port]
  end

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :fixed_gear, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :fixed_gear, FixedGearWeb.Endpoint, secret_key_base: secret_key_base
end
