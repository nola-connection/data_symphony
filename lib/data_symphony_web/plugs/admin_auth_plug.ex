defmodule DataSymphonyWeb.AdminAuthPlug do
  @moduledoc """
  Plug for authenticating admin access to LiveDashboard and other protected routes.

  In development, all access is allowed. In production, requires HTTP Basic Auth
  with credentials from environment variables:
  - ADMIN_USERNAME
  - ADMIN_PASSWORD

  TODO(F-5): The `/dev` scope in the router is compile-gated on `:dev_routes`,
  which is currently only true in dev/test, so this plug bypasses auth wherever
  the route exists and never reaches `authenticate_admin/1`. Real staging /
  production enforcement (a non-local environment that exposes LiveDashboard)
  is wired up as part of the Fly.io deploy scaffold (F-5); until that lands this
  module is scaffolding and the credential logic below is intentionally dormant.
  """

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    if Application.get_env(:data_symphony, :dev_routes) do
      conn
    else
      authenticate_admin(conn)
    end
  end

  defp authenticate_admin(conn) do
    with {username, password} <- Plug.BasicAuth.parse_basic_auth(conn),
         true <- valid_credentials?(username, password) do
      conn
    else
      _ -> conn |> Plug.BasicAuth.request_basic_auth(realm: "admin") |> halt()
    end
  end

  defp valid_credentials?(username, password) do
    expected_username = System.get_env("ADMIN_USERNAME", "admin")
    expected_password = System.get_env("ADMIN_PASSWORD")

    case expected_password do
      nil ->
        false

      _ ->
        # Compute both comparisons before combining to avoid short-circuit
        # timing leaks; secure_compare/2 is itself constant-time.
        valid_username? = Plug.Crypto.secure_compare(username, expected_username)
        valid_password? = Plug.Crypto.secure_compare(password, expected_password)
        valid_username? and valid_password?
    end
  end
end
