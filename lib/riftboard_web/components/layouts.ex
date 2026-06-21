defmodule RiftboardWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use RiftboardWeb, :controller` and
  `use RiftboardWeb, :live_view`.
  """
  use RiftboardWeb, :html

  embed_templates "layouts/*"
end
