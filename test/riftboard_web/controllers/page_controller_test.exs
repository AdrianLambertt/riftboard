defmodule RiftboardWeb.PageControllerTest do
  use RiftboardWeb.ConnCase

  test "GET / redirects to /boards", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/boards"
  end
end
