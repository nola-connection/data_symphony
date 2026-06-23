defmodule DataSymphonyWeb.AdminAuthPlug do
  @moduledoc """
  Plug for authenticating admin access to LiveDashboard and other protected routes.

  In development (`:dev_routes` enabled) all access is allowed. On staging and
  production the router mounts the `/dev` LiveDashboard scope unconditionally
  (see `DataSymphonyWeb.Router`), so this plug enforces HTTP Basic Auth using
  credentials from environment variables:
  - ADMIN_USERNAME (defaults to "admin")
  - ADMIN_PASSWORD (required; access is denied when unset)

  Set these on the Fly app via `fly secrets set` — never commit them.
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
