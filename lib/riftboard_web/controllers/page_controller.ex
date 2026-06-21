defmodule RiftboardWeb.PageController do
  use RiftboardWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/boards")
  end
end
