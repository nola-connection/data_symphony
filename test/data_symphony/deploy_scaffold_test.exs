defmodule DataSymphony.DeployScaffoldTest do
  @moduledoc """
  Guards F-5: Fly.io deploy scaffold acceptance criteria.

  1. `fly.toml` and release config committed.
  2. Secrets managed via Fly secrets, not source.
  3. Staging deploy succeeds automatically from `main`.
  """
  use ExUnit.Case, async: true

  import Bitwise, only: [&&&: 2]

  @root Path.expand("../..", __DIR__)

  defp read(relative), do: File.read!(Path.join(@root, relative))
  defp exists?(relative), do: File.exists?(Path.join(@root, relative))

  describe "criterion 1: fly.toml and release config committed" do
    test "both fly configs and the docker build files exist" do
      assert exists?("fly.toml")
      assert exists?("fly.staging.toml")
      assert exists?("Dockerfile")
      assert exists?(".dockerignore")
    end

    test "release module exposes migrate/0 and rollback/2" do
      Code.ensure_loaded!(DataSymphony.Release)
      assert function_exported?(DataSymphony.Release, :migrate, 0)
      assert function_exported?(DataSymphony.Release, :rollback, 2)
    end

    test "release overlay entrypoints are present and executable" do
      for {script, expected} <- [
            {"rel/overlays/bin/server", "data_symphony start"},
            {"rel/overlays/bin/migrate", "DataSymphony.Release.migrate"}
          ] do
        path = Path.join(@root, script)
        assert File.exists?(path)
        contents = File.read!(path)
        assert String.starts_with?(contents, "#!/bin/sh")
        assert contents =~ expected
        %File.Stat{mode: mode} = File.stat!(path)
        assert (mode &&& 0o100) != 0, "#{script} should be executable"
      end
    end

    test "Dockerfile builds a release and boots via the server overlay" do
      dockerfile = read("Dockerfile")
      assert dockerfile =~ "mix release"
      assert dockerfile =~ ~s(CMD ["/app/bin/server"])
    end

    test "both fly configs run migrations as the release command" do
      assert read("fly.toml") =~ "release_command = '/app/bin/migrate'"
      assert read("fly.staging.toml") =~ "release_command = '/app/bin/migrate'"
    end
  end

  describe "staging is kept separate from prod" do
    test "fly configs target different Fly apps" do
      assert read("fly.toml") =~ "app = 'data-symphony'"
      assert read("fly.staging.toml") =~ "app = 'data-symphony-staging'"
      refute read("fly.toml") =~ "app = 'data-symphony-staging'"
    end
  end

  describe "criterion 2: secrets managed via Fly secrets, not source" do
    @secret_keys ~w(SECRET_KEY_BASE DATABASE_URL ADMIN_PASSWORD)

    # Strip TOML comment lines so documentation examples (e.g. a commented
    # `fly secrets set SECRET_KEY_BASE=...` hint) don't count as assignments.
    defp config_body(relative) do
      relative
      |> read()
      |> String.split("\n")
      |> Enum.reject(&(&1 |> String.trim_leading() |> String.starts_with?("#")))
      |> Enum.join("\n")
    end

    test "fly configs never assign secret values" do
      for config <- ["fly.toml", "fly.staging.toml"], key <- @secret_keys do
        refute config_body(config) =~ ~r/#{key}\s*=/,
               "#{config} must not assign #{key}; use `fly secrets set`"
      end
    end

    test "Dockerfile does not bake secrets into the image" do
      dockerfile = read("Dockerfile")

      for key <- @secret_keys do
        refute dockerfile =~ ~r/ENV\s+#{key}/, "Dockerfile must not set #{key}"
      end
    end
  end

  describe "criterion 3: staging deploys automatically from main" do
    @workflow ".github/workflows/deploy-staging.yml"

    test "a deploy workflow is committed" do
      assert exists?(@workflow)
    end

    test "the workflow triggers on push to main" do
      workflow = read(@workflow)
      assert workflow =~ ~r/on:\s*\n\s*push:/
      assert workflow =~ ~r/branches:\s*\n\s*-\s*main/
    end

    test "the workflow deploys the staging config to the staging app" do
      workflow = read(@workflow)
      assert workflow =~ "flyctl deploy"
      assert workflow =~ "--config fly.staging.toml"
      assert workflow =~ "data-symphony-staging"
    end

    test "the workflow authenticates via the FLY_API_TOKEN secret, not a literal" do
      workflow = read(@workflow)
      assert workflow =~ "FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}"
    end
  end
end
