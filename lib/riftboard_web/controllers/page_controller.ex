defmodule RiftboardWeb.PageController do
  use RiftboardWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/boards")
    else
      redirect(conn, to: ~p"/users/log_in")
    end
  end
end
