defmodule RiftboardWeb.UserSessionController do
  use RiftboardWeb, :controller

  alias Riftboard.Accounts
  alias RiftboardWeb.UserAuth

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => %{"username" => username, "password" => password}}, info) do
    if user = Accounts.get_user_by_username_and_password(username, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user)
    else
      conn
      |> put_flash(:error, "Invalid username or password")
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def guest_login(conn, _params) do
    case Accounts.register_guest_user() do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome, #{user.display_name}!")
        |> UserAuth.log_in_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Something went wrong, please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
