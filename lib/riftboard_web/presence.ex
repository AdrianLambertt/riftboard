defmodule RiftboardWeb.Presence do
  @moduledoc "Tracks viewers currently present on a board, keyed by LiveView socket id."

  use Phoenix.Presence,
    otp_app: :riftboard,
    pubsub_server: Riftboard.PubSub
end
