defmodule DataSymphonyWeb.AdminAuthEnforcementTest do
  @moduledoc """
  F-5: outside dev (`:dev_routes` disabled) the LiveDashboard `/dev` scope is
  still mounted, so `AdminAuthPlug` must enforce HTTP Basic Auth. This covers
  the staging/production enforcement that the F-5 deploy scaffold wires up.

  Mutates global application/system env, so it runs synchronously.
  """
  use ExUnit.Case, async: false

  import Plug.Conn

  alias DataSymphonyWeb.AdminAuthPlug

  setup do
    prev_dev_routes = Application.get_env(:data_symphony, :dev_routes)
    prev_user = System.get_env("ADMIN_USERNAME")
    prev_pass = System.get_env("ADMIN_PASSWORD")

    # Simulate a non-local (staging/prod) release that exposes LiveDashboard.
    Application.put_env(:data_symphony, :dev_routes, false)
    System.put_env("ADMIN_USERNAME", "admin")
    System.put_env("ADMIN_PASSWORD", "s3cret")

    on_exit(fn ->
      restore_app_env(:dev_routes, prev_dev_routes)
      restore_system_env("ADMIN_USERNAME", prev_user)
      restore_system_env("ADMIN_PASSWORD", prev_pass)
    end)

    :ok
  end

  defp restore_app_env(key, nil), do: Application.delete_env(:data_symphony, key)
  defp restore_app_env(key, value), do: Application.put_env(:data_symphony, key, value)

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)

  defp request(authorization \\ nil) do
    conn = Phoenix.ConnTest.build_conn(:get, "/dev/dashboard")
    conn = if authorization, do: put_req_header(conn, "authorization", authorization), else: conn
    AdminAuthPlug.call(conn, [])
  end

  defp basic(user, pass), do: "Basic " <> Base.encode64("#{user}:#{pass}")

  test "challenges with Basic Auth when no credentials are supplied" do
    conn = request()

    assert conn.halted
    assert conn.status == 401
    assert get_resp_header(conn, "www-authenticate") != []
  end

  test "rejects invalid credentials" do
    conn = request(basic("admin", "wrong"))

    assert conn.halted
    assert conn.status == 401
  end

  test "allows access with valid credentials" do
    conn = request(basic("admin", "s3cret"))

    refute conn.halted
  end

  test "denies access when ADMIN_PASSWORD is unset, even with a matching user" do
    System.delete_env("ADMIN_PASSWORD")
    conn = request(basic("admin", ""))

    assert conn.halted
    assert conn.status == 401
  end
end
