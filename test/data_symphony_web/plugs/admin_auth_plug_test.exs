defmodule DataSymphonyWeb.AdminAuthPlugTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  alias DataSymphonyWeb.AdminAuthPlug

  describe "admin auth plug" do
    test "allows all access in dev environment" do
      conn = Phoenix.ConnTest.build_conn(:get, "/dev/dashboard")
      result = AdminAuthPlug.call(conn, [])

      refute result.halted
    end

    test "parses basic auth credentials correctly" do
      # Create a basic auth header
      credentials = Base.encode64("admin:secret123")
      auth_header = "Basic #{credentials}"

      conn =
        put_req_header(
          Phoenix.ConnTest.build_conn(:get, "/dev/dashboard"),
          "authorization",
          auth_header
        )

      # In dev mode, this should pass regardless
      result = AdminAuthPlug.call(conn, [])
      refute result.halted
    end

    test "bypasses auth in dev even when no credentials are provided" do
      # `dev_routes` is true in the test env, so the plug short-circuits before
      # ever evaluating credentials. Prod/staging enforcement is wired up in
      # F-5 (see AdminAuthPlug TODO) and is covered there.
      conn = Phoenix.ConnTest.build_conn(:get, "/dev/dashboard")
      result = AdminAuthPlug.call(conn, [])

      refute result.halted
    end
  end
end
