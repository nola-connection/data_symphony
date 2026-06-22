defmodule DataSymphony.ToolVersionsTest do
  @moduledoc """
  Verifies that the Elixir/OTP toolchain is pinned (`.tool-versions`) and that
  the pinned versions are consistent with `mix.exs` and the running runtime.

  This guards acceptance criterion F-1: "Elixir/OTP versions pinned and
  documented".
  """
  use ExUnit.Case, async: true

  @tool_versions_path Path.expand("../../.tool-versions", __DIR__)
  @readme_path Path.expand("../../README.md", __DIR__)

  setup_all do
    contents = File.read!(@tool_versions_path)

    pins =
      contents
      |> String.split("\n", trim: true)
      |> Enum.map(&String.split(&1, ~r/\s+/, trim: true))
      |> Enum.into(%{}, fn [tool | rest] -> {tool, List.first(rest)} end)

    {:ok, pins: pins}
  end

  test ".tool-versions exists and pins both erlang and elixir", %{pins: pins} do
    assert File.exists?(@tool_versions_path)
    assert Map.has_key?(pins, "erlang")
    assert Map.has_key?(pins, "elixir")
    refute pins["erlang"] in [nil, ""]
    refute pins["elixir"] in [nil, ""]
  end

  test "pinned elixir version matches the running runtime", %{pins: pins} do
    # `.tool-versions` uses entries like "1.15.8-otp-25"; compare the leading
    # MAJOR.MINOR.PATCH against the running Elixir version.
    pinned_elixir = pins["elixir"] |> String.split("-") |> List.first()
    assert pinned_elixir == System.version()
  end

  test "pinned erlang version matches the running OTP release", %{pins: pins} do
    pinned_otp_major = pins["erlang"] |> String.split(".") |> List.first()
    assert pinned_otp_major == List.to_string(:erlang.system_info(:otp_release))
  end

  test "pinned elixir version satisfies the mix.exs requirement", %{pins: pins} do
    requirement = Mix.Project.config()[:elixir]
    pinned_elixir = pins["elixir"] |> String.split("-") |> List.first()
    assert Version.match?(pinned_elixir, requirement)
  end

  test "README documents the pinned toolchain", %{pins: pins} do
    readme = File.read!(@readme_path)
    pinned_elixir = pins["elixir"] |> String.split("-") |> List.first()
    assert String.contains?(readme, ".tool-versions")
    assert String.contains?(readme, pinned_elixir)
  end
end
