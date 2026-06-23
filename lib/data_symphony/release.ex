defmodule DataSymphony.Release do
  @moduledoc """
  Tasks that run inside the assembled `mix release`, where Mix itself is not
  available.

  `migrate/0` is invoked automatically on every Fly.io deploy via the
  `release_command` in `fly.toml`/`fly.staging.toml` (which calls the
  `bin/migrate` overlay). It can also be run manually against a running
  machine with:

      bin/data_symphony eval "DataSymphony.Release.migrate"
  """
  @app :data_symphony

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
