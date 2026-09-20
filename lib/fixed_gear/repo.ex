defmodule FixedGear.Repo do
  use Ecto.Repo,
    otp_app: :fixed_gear,
    adapter: Ecto.Adapters.Postgres
end
