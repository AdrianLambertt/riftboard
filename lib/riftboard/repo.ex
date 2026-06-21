defmodule Riftboard.Repo do
  use Ecto.Repo,
    otp_app: :riftboard,
    adapter: Ecto.Adapters.Postgres
end
