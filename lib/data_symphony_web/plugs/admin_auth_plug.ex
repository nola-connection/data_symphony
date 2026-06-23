defmodule DataSymphonyWeb.AdminAuthPlug do
  @moduledoc """
  Plug for authenticating admin access to LiveDashboard and other protected routes.

  In development, all access is allowed. In production, requires HTTP Basic Auth
  with credentials from environment variables:
  - ADMIN_USERNAME
  - ADMIN_PASSWORD
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
    case parse_credentials(conn) do
      {username, password} ->
        if valid_credentials?(username, password) do
          conn
        else
          unauthorized(conn)
        end

      :error ->
        unauthorized(conn)
    end
  end

  defp parse_credentials(conn) do
    with [auth_header] <- Plug.Conn.get_req_header(conn, "authorization"),
         ["Basic", encoded] <- String.split(auth_header),
         {:ok, decoded} <- Base.decode64(encoded),
         [username, password] <- String.split(decoded, ":", parts: 2) do
      {username, password}
    else
      _ -> :error
    end
  end

  defp valid_credentials?(username, password) do
    expected_username = System.get_env("ADMIN_USERNAME", "admin")
    expected_password = System.get_env("ADMIN_PASSWORD")

    case expected_password do
      nil ->
        false

      _ ->
        username == expected_username and
          password == expected_password
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"admin\"")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
