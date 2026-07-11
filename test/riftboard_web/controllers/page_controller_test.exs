defmodule RiftboardWeb.PageControllerTest do
  use RiftboardWeb.ConnCase

  import Riftboard.AccountsFixtures

  test "GET / redirects to /boards when logged in", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/")
    assert redirected_to(conn) == ~p"/boards"
  end

  test "GET / redirects to /users/log_in when logged out", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log_in"
  end
end
