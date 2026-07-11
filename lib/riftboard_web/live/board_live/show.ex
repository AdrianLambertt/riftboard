defmodule RiftboardWeb.BoardLive.Show do
  use RiftboardWeb, :live_view
  alias Riftboard.Boards
  alias Riftboard.Boards.{Card, Column}
  alias RiftboardWeb.Presence

  def mount(%{"id" => id}, _session, socket) do
    topic = "board:#{id}"
    # Subscribe before fetching so a concurrent update landing in between isn't missed.
    if connected?(socket), do: Phoenix.PubSub.subscribe(Riftboard.PubSub, topic)

    case Boards.get_board_with_columns_and_cards(id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/boards")}

      board ->
        current_user = socket.assigns.current_user

        # Keyed by the stable user id so multiple tabs from the same user
        # collapse into one presence entry instead of stacking duplicates.
        if connected?(socket) do
          {:ok, _} =
            Presence.track(self(), topic, to_string(current_user.id), %{
              name: current_user.display_name,
              color: current_user.color
            })
        end

        {:ok,
         socket
         |> assign(:board, board)
         |> assign(:adding_column, false)
         |> assign(:column_form, nil)
         |> assign(:adding_card_to, nil)
         |> assign(:card_form, nil)
         |> assign(:active_card, nil)
         |> assign(:card_edit_form, nil)
         |> assign(:presences, list_presences(topic))}
    end
  end

  def handle_info({:board_updated, board}, socket) do
    {:noreply, assign(socket, board: board)}
  end

  def handle_info(:board_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "This board was deleted.")
     |> push_navigate(to: ~p"/boards")}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :presences, list_presences("board:#{socket.assigns.board.id}"))}
  end

  defp list_presences(topic) do
    topic
    |> Presence.list()
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
  end

  # --- Columns ---

  def handle_event("show_add_column", _params, socket) do
    form = to_form(Column.changeset(%Column{}, %{}))
    {:noreply, assign(socket, adding_column: true, column_form: form)}
  end

  def handle_event("cancel_add_column", _params, socket) do
    {:noreply, assign(socket, adding_column: false, column_form: nil)}
  end

  def handle_event("save_column", %{"column" => params}, socket) do
    case Boards.create_column_for_board(socket.assigns.board, params) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           adding_column: false,
           column_form: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, column_form: to_form(changeset))}
    end
  end

  def handle_event("delete_column", %{"id" => id}, socket) do
    {:ok, _} = Boards.delete_column(Boards.get_column(id))
    {:noreply, socket}
  end

  # --- Cards ---

  def handle_event("show_add_card", %{"column_id" => column_id}, socket) do
    # A unique id per column ensures switching directly between columns' forms
    # is a genuine remove+insert (so the AutoFocus hook remounts), not a DOM
    # node move — the id would otherwise be identical ("card_title") every time.
    form = to_form(Card.changeset(%Card{}, %{}), id: "card-form-#{column_id}")

    {:noreply, assign(socket, adding_card_to: column_id, card_form: form)}
  end

  def handle_event("cancel_add_card", _params, socket) do
    {:noreply, assign(socket, adding_card_to: nil, card_form: nil)}
  end

  def handle_event("save_card", %{"card" => params}, socket) do
    column = Boards.get_column(socket.assigns.adding_card_to)

    case Boards.create_card_for_column(column, params) do
      {:ok, _} ->
        {:noreply, assign(socket, adding_card_to: nil, card_form: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, card_form: to_form(changeset))}
    end
  end

  def handle_event("open_card", %{"id" => id}, socket) do
    card = Boards.get_card(id)

    {:noreply,
     assign(socket, active_card: card, card_edit_form: to_form(Card.changeset(card, %{})))}
  end

  def handle_event("close_card", _params, socket) do
    {:noreply, assign(socket, active_card: nil, card_edit_form: nil)}
  end

  def handle_event("validate_card", %{"card" => params}, socket) do
    form =
      socket.assigns.active_card
      |> Card.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, card_edit_form: form)}
  end

  def handle_event("update_card", %{"card" => params}, socket) do
    changeset = Card.changeset(socket.assigns.active_card, params)

    case Boards.update_card(changeset) do
      {:ok, _} ->
        {:noreply,
         assign(socket,
           active_card: nil,
           card_edit_form: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, card_edit_form: to_form(changeset))}
    end
  end

  def handle_event("delete_card", %{"id" => id}, socket) do
    card = Boards.get_card(id)
    {:ok, _} = Boards.delete_card(card)

    {:noreply,
     assign(socket,
       active_card: nil,
       card_edit_form: nil
     )}
  end

  def handle_event(
        "card_moved",
        %{"card_id" => card_id, "column_id" => column_id, "position" => position},
        socket
      ) do
    card = Boards.get_card(card_id)
    {:ok, _} = Boards.move_card(card, column_id, position)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-3 mb-6">
      <.link navigate={~p"/boards"} class="text-zinc-400 transition-colors hover:text-zinc-600">
        <.icon name="hero-arrow-left" class="h-5 w-5" />
      </.link>

      <h1 class="text-lg font-bold text-zinc-900">{@board.name}</h1>

      <div class="ml-auto flex -space-x-2">
        <div
          :for={presence <- @presences}
          title={presence.name}
          class="flex h-7 w-7 items-center justify-center rounded-full text-xs font-semibold text-white ring-2 ring-white"
          style={"background-color: #{presence.color}"}
        >
          {String.first(presence.name)}
        </div>
      </div>
    </div>

    <div class="flex items-start gap-3 overflow-x-auto pb-6">
      <div
        :for={column <- @board.columns}
        id={"column-#{column.id}"}
        class="flex w-72 flex-shrink-0 flex-col rounded-xl bg-zinc-100"
        style="max-height: calc(100vh - 11rem)"
      >
        <div class="flex items-center justify-between px-3 pb-2 pt-3">
          <h2 class="text-sm font-semibold text-zinc-700">{column.name}</h2>

          <button
            phx-click="delete_column"
            phx-value-id={column.id}
            data-confirm={"Delete '#{column.name}' and all its cards?"}
            class="p-1 text-zinc-300 transition-colors hover:text-rose-400"
          >
            <.icon name="hero-x-mark" class="h-4 w-4" />
          </button>
        </div>

        <div
          id={"cards-#{column.id}"}
          data-column-id={column.id}
          phx-hook="Sortable"
          class="flex-1 space-y-2 overflow-y-auto px-3 pb-2"
        >
          <div
            :for={card <- column.cards}
            id={"card-#{card.id}"}
            data-card-id={card.id}
            phx-click="open_card"
            phx-value-id={card.id}
            class="cursor-pointer rounded-lg bg-white px-3 py-2.5 shadow-sm transition-shadow hover:shadow"
          >
            <p class="text-sm font-medium leading-snug text-zinc-900">{card.title}</p>

            <p
              :if={card.description && card.description != ""}
              class="mt-1 line-clamp-2 text-xs text-zinc-500"
            >
              {card.description}
            </p>
          </div>

          <div :if={@adding_card_to == column.id} class="rounded-lg bg-white px-3 py-2 shadow-sm">
            <.form for={@card_form} phx-submit="save_card">
              <input
                type="text"
                name={@card_form[:title].name}
                id={@card_form[:title].id}
                placeholder="Card title…"
                required
                phx-hook="AutoFocus"
                phx-keydown="cancel_add_card"
                phx-key="Escape"
                class="w-full border-0 bg-transparent p-0 text-sm text-zinc-900 placeholder-zinc-400 outline-none focus:ring-0"
              />
              <div class="mt-2 flex items-center gap-2">
                <button
                  type="submit"
                  class="rounded bg-zinc-900 px-2 py-1 text-xs font-semibold text-white hover:bg-zinc-700"
                >
                  Add
                </button>

                <button
                  type="button"
                  phx-click="cancel_add_card"
                  class="p-1 text-zinc-400 hover:text-zinc-600"
                >
                  <.icon name="hero-x-mark" class="h-4 w-4" />
                </button>
              </div>
            </.form>
          </div>
        </div>

        <div :if={@adding_card_to != column.id} class="px-3 pb-3 pt-1">
          <button
            phx-click="show_add_card"
            phx-value-column_id={column.id}
            class="flex w-full items-center gap-1.5 rounded-lg px-2 py-1.5 text-sm text-zinc-500 transition-colors hover:bg-zinc-200 hover:text-zinc-700"
          >
            <.icon name="hero-plus" class="h-4 w-4" /> Add a card
          </button>
        </div>
      </div>

      <div class="w-72 flex-shrink-0">
        <div :if={@adding_column} class="rounded-xl bg-zinc-100 px-3 py-3">
          <.form for={@column_form} phx-submit="save_column">
            <input
              type="text"
              name={@column_form[:name].name}
              id={@column_form[:name].id}
              placeholder="Column name…"
              required
              autofocus
              phx-keydown="cancel_add_column"
              phx-key="Escape"
              class="w-full rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 placeholder-zinc-400 focus:border-zinc-400 focus:outline-none focus:ring-0"
            />
            <div class="mt-2 flex items-center gap-2">
              <button
                type="submit"
                class="rounded bg-zinc-900 px-2 py-1 text-xs font-semibold text-white hover:bg-zinc-700"
              >
                Add column
              </button>

              <button
                type="button"
                phx-click="cancel_add_column"
                class="p-1 text-zinc-400 hover:text-zinc-600"
              >
                <.icon name="hero-x-mark" class="h-4 w-4" />
              </button>
            </div>
          </.form>
        </div>

        <button
          :if={!@adding_column}
          phx-click="show_add_column"
          class="flex w-full items-center gap-1.5 rounded-xl bg-zinc-900/10 px-3 py-2.5 text-sm font-medium text-zinc-600 transition-colors hover:bg-zinc-900/20"
        >
          <.icon name="hero-plus" class="h-4 w-4" /> Add a column
        </button>
      </div>
    </div>

    <.modal :if={@active_card} id="card-modal" show on_cancel={JS.push("close_card")}>
      <.form for={@card_edit_form} phx-change="validate_card" phx-submit="update_card">
        <.input field={@card_edit_form[:title]} label="Title" phx-debounce="blur" />
        <div class="mt-4">
          <.input type="textarea" field={@card_edit_form[:description]} label="Description" rows="4" />
        </div>

        <div class="mt-6 flex items-center justify-between">
          <button
            type="button"
            phx-click="delete_card"
            phx-value-id={@active_card.id}
            data-confirm="Delete this card?"
            class="text-sm font-medium text-rose-500 hover:text-rose-700"
          >
            Delete card
          </button>

          <div class="flex items-center gap-3">
            <button
              type="button"
              phx-click="close_card"
              class="text-sm text-zinc-500 hover:text-zinc-700"
            >
              Cancel
            </button>

            <.button type="submit">Save</.button>
          </div>
        </div>
      </.form>
    </.modal>
    """
  end
end
