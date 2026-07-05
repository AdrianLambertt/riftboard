defmodule RiftboardWeb.BoardLive.Index do
  use RiftboardWeb, :live_view
  alias Riftboard.Boards
  alias Riftboard.Boards.Board

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Riftboard.PubSub, "board_updates")
    end

    {:ok, assign(socket, boards: Boards.list_boards_with_columns(), form: nil)}
  end

  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :new ->
        {:noreply, assign(socket, form: to_form(Board.changeset(%Board{}, %{})))}

      :index ->
        {:noreply, assign(socket, form: nil)}
    end
  end

  def handle_event("validate", %{"board" => params}, socket) do
    form =
      %Board{}
      |> Board.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"board" => params}, socket) do
    case Boards.create_board(Board.changeset(%Board{}, params)) do
      {:ok, board} ->
        {:noreply, push_navigate(socket, to: ~p"/boards/#{board.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete_board", %{"id" => id}, socket) do
    {:ok, _} = Boards.delete_board(Boards.get_board(id))
    {:noreply, socket}
  end

  def handle_info({:board_updates, {%Board{} = updated_board, action}}, socket) do
    {:noreply, assign(socket, boards: alter_board(socket.assigns.boards, updated_board, action))}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <div class="mb-6 flex items-center justify-between">
        <h1 class="text-lg font-bold text-zinc-900">Boards</h1>
        <.link
          navigate={~p"/boards/new"}
          class="inline-flex items-center gap-1.5 rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          <.icon name="hero-plus" class="h-4 w-4" /> New Board
        </.link>
      </div>

      <div :if={@boards == []} class="py-20 text-center text-zinc-400">
        <p class="text-base font-medium">No boards yet</p>
        <p class="mt-1 text-sm">Create one to get started.</p>
      </div>

      <div class="divide-y divide-zinc-100 overflow-hidden rounded-xl border border-zinc-200 bg-white">
        <div :for={board <- @boards} id={"board-#{board.id}"} class="group flex items-stretch">
          <.link
            navigate={~p"/boards/#{board.id}"}
            class="flex-1 px-6 py-4 transition-colors hover:bg-zinc-50"
          >
            <div class="flex items-baseline justify-between">
              <span class="text-sm font-semibold text-zinc-900">{board.name}</span>
              <span class="text-xs text-zinc-400">
                {Calendar.strftime(board.inserted_at, "%b %d, %Y")}
              </span>
            </div>

            <div :if={board.columns != []} class="mt-3 flex items-end gap-8">
              <div :for={column <- board.columns}>
                <div class="text-xs font-medium uppercase tracking-wide text-zinc-400">
                  {column.name}
                </div>
                <div class="mt-0.5 text-2xl font-bold leading-none text-zinc-800">
                  {length(column.cards)}
                </div>
              </div>
            </div>

            <div :if={board.columns == []} class="mt-2 text-sm italic text-zinc-400">
              No columns yet
            </div>
          </.link>

          <div class="flex w-12 flex-shrink-0 items-start justify-center pt-4 opacity-0 transition-opacity group-hover:opacity-100">
            <button
              phx-click="delete_board"
              phx-value-id={board.id}
              data-confirm={"Delete '#{board.name}'?"}
              class="p-1.5 text-zinc-300 transition-colors hover:text-rose-500"
            >
              <.icon name="hero-trash" class="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <.modal :if={@live_action == :new} id="new-board-modal" show on_cancel={JS.navigate(~p"/boards")}>
      <.header>New Board</.header>
      <.simple_form for={@form} phx-change="validate" phx-submit="save" class="mt-6">
        <.input field={@form[:name]} label="Name" placeholder="e.g. Sprint 1" autofocus />
        <:actions>
          <.button type="submit">Create Board</.button>
          <.link navigate={~p"/boards"} class="text-sm text-zinc-500 hover:text-zinc-700">
            Cancel
          </.link>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  defp alter_board(boards, action_board, :add) do
    boards ++ [action_board]
  end

  defp alter_board(boards, action_board, :update) do
    id = action_board.id

    Enum.map(boards, fn
      %{id: ^id} -> action_board
      board -> board
    end)
  end

  defp alter_board(boards, action_board, :delete) do
    Enum.reject(boards, &(&1.id == action_board.id))
  end
end
