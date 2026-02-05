defmodule KC.Repo do
  use Ecto.Repo,
    otp_app: :kc_core,
    adapter: Ecto.Adapters.Postgres
end
