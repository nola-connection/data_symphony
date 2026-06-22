defmodule DataSymphony.Repo do
  use Ecto.Repo,
    otp_app: :data_symphony,
    adapter: Ecto.Adapters.Postgres
end
