defmodule Riftboard.Boards do
  @moduledoc "Context for managing boards, columns, and cards."

  import Ecto.Query
  alias Riftboard.Boards.{Board, Card, Column}
  alias Riftboard.Repo

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  # Broadcasts a board add/update/delete to the "board_updates" topic, consumed by
  # BoardLive.Index to keep the board list overview in sync. Pass a {:ok, _} | {:error, _}
  # result tuple directly from the Repo call; errors are silently ignored.
  # For updates to a single board's contents (columns/cards), see broadcast_show_update/1,
  # which notifies BoardLive.Show instead.
  defp broadcast_index_update({:error, _}, _), do: :pass

  # A board that's already been concurrently deleted has nothing to announce.
  defp broadcast_index_update({:ok, nil}, _), do: :pass

  defp broadcast_index_update({:ok, board}, action) when action in [:add, :update, :delete] do
    Phoenix.PubSub.broadcast(Riftboard.PubSub, "board_updates", {:board_updates, {board, action}})
  end

  # Broadcasts a board's current state to the "board:#{board_id}" topic, consumed by
  # BoardLive.Show to keep a single board's columns/cards in sync across connected clients.
  # For the board list overview, see broadcast_index_update/2, which notifies BoardLive.Index.
  defp broadcast_show_update(%Board{} = board) do
    Phoenix.PubSub.broadcast(Riftboard.PubSub, "board:#{board.id}", {:board_updated, board})
  end

  defp broadcast_show_update(nil), do: :pass

  defp broadcast_show_update(board_id) do
    case get_board_with_columns_and_cards(board_id) do
      nil ->
        :pass

      board ->
        Phoenix.PubSub.broadcast(Riftboard.PubSub, "board:#{board_id}", {:board_updated, board})
    end
  end

  defp broadcast_show_delete(board_id) do
    Phoenix.PubSub.broadcast(Riftboard.PubSub, "board:#{board_id}", :board_deleted)
  end

  # ---------------------------------------------------------------------------
  # Boards
  # ---------------------------------------------------------------------------

  def list_boards do
    Repo.all(Board)
  end

  def list_boards_with_columns do
    Board
    |> order_by([b], desc: b.inserted_at)
    |> Repo.all()
    |> Repo.preload(columns: {from(c in Column, order_by: c.position), :cards})
  end

  def get_board(id) do
    Repo.get(Board, id)
  end

  def get_board_with_columns_and_cards(id) do
    Repo.get(Board, id)
    |> Repo.preload(
      columns:
        {from(c in Column, order_by: c.position),
         cards: {from(c in Card, order_by: [asc: c.position]), []}}
    )
  end

  def create_board(changeset) do
    result =
      Repo.transact(fn ->
        with {:ok, board} <- Repo.insert(changeset),
             {:ok, _col} <- insert_column(board, %{"name" => "To Do"}) do
          {:ok, Repo.preload(board, columns: :cards)}
        end
      end)

    broadcast_index_update(result, :add)
    result
  end

  def update_board(changeset) do
    result = Repo.update(changeset)
    broadcast_index_update(result, :update)
    result
  end

  def delete_board(board) do
    result = Repo.delete(board)
    broadcast_index_update(result, :delete)

    with {:ok, _} <- result do
      broadcast_show_delete(board.id)
    end

    result
  end

  # ---------------------------------------------------------------------------
  # Columns
  # ---------------------------------------------------------------------------

  def get_column(id), do: Repo.get(Column, id)

  def create_column_for_board(%Board{id: board_id} = board, attrs) do
    result = insert_column(board, attrs)

    with {:ok, _} <- result do
      board = get_board_with_columns_and_cards(board_id)
      broadcast_index_update({:ok, board}, :update)
      broadcast_show_update(board)
    end

    result
  end

  # Used directly by create_board/1 for the initial "To Do" column, bypassing
  # create_column_for_board/2's broadcasts: that column is created inside
  # create_board's own transaction, before the board exists to any subscriber,
  # and create_board broadcasts the finished board itself once it commits.
  defp insert_column(%Board{id: board_id}, attrs) do
    next_pos =
      from(c in Column, where: c.board_id == ^board_id, select: max(c.position))
      |> Repo.one()
      |> case do
        nil -> 0
        pos -> pos + 1
      end

    %Column{}
    |> Column.changeset(attrs)
    |> Ecto.Changeset.put_change(:position, next_pos)
    |> Ecto.Changeset.put_change(:board_id, board_id)
    |> Repo.insert()
  end

  def create_column(changeset) do
    Repo.insert(changeset)
  end

  def update_column(changeset) do
    Repo.update(changeset)
  end

  def delete_column(column) do
    result = Repo.delete(column)

    with {:ok, _} <- result do
      board = get_board_with_columns_and_cards(column.board_id)
      broadcast_index_update({:ok, board}, :update)
      broadcast_show_update(board)
    end

    result
  end

  # ---------------------------------------------------------------------------
  # Cards
  # ---------------------------------------------------------------------------

  def get_card(id), do: Repo.get(Card, id)

  def create_card_for_column(%Column{id: column_id, board_id: board_id}, attrs) do
    next_pos =
      from(c in Card, where: c.column_id == ^column_id, select: max(c.position))
      |> Repo.one()
      |> case do
        nil -> 0
        pos -> pos + 1
      end

    result =
      %Card{}
      |> Card.changeset(attrs)
      |> Ecto.Changeset.put_change(:position, next_pos)
      |> Ecto.Changeset.put_change(:column_id, column_id)
      |> Repo.insert()

    with {:ok, _} <- result do
      board = get_board_with_columns_and_cards(board_id)
      broadcast_index_update({:ok, board}, :update)
      broadcast_show_update(board)
    end

    result
  end

  def create_card(changeset) do
    Repo.insert(changeset)
  end

  def update_card(changeset) do
    result = Repo.update(changeset)

    with {:ok, card} <- result,
         board_id when not is_nil(board_id) <- board_id_for_card(card) do
      broadcast_show_update(board_id)
    end

    result
  end

  def delete_card(card) do
    result = Repo.delete(card)

    with {:ok, _} <- result,
         board_id when not is_nil(board_id) <- board_id_for_card(card) do
      board = get_board_with_columns_and_cards(board_id)
      broadcast_index_update({:ok, board}, :update)
      broadcast_show_update(board)
    end

    result
  end

  def move_card(card, column_id, position) do
    result =
      Repo.transact(fn ->
        if card.column_id == column_id do
          same_column_move(card, position)
        else
          cross_column_move(card, column_id, position)
        end
      end)

    # Dropping a card back on its own position is a no-op (see same_column_move/2
    # below); skip broadcasting since nothing actually changed.
    moved? = card.column_id != column_id or position != card.position

    with {:ok, _} <- result,
         true <- moved?,
         board_id when not is_nil(board_id) <- board_id_for_card(card) do
      if card.column_id == column_id do
        broadcast_show_update(board_id)
      else
        board = get_board_with_columns_and_cards(board_id)
        broadcast_index_update({:ok, board}, :update)
        broadcast_show_update(board)
      end
    end

    result
  end

  # Cards only store their column_id; this resolves the owning board for
  # broadcasting, tolerating a column that's been concurrently deleted (nil)
  # rather than crashing (see update_card/1, delete_card/1, move_card/3).
  defp board_id_for_card(card) do
    case get_column(card.column_id) do
      nil -> nil
      column -> column.board_id
    end
  end

  defp same_column_move(card, target) when target == card.position do
    {:ok, card}
  end

  defp same_column_move(card, target) when target < card.position do
    from(c in Card,
      where:
        c.column_id == ^card.column_id and c.position >= ^target and c.position < ^card.position
    )
    |> Repo.update_all(inc: [position: 1])

    Card.move_changeset(card, %{column_id: card.column_id, position: target})
    |> Repo.update()
  end

  defp same_column_move(card, target) do
    from(c in Card,
      where:
        c.column_id == ^card.column_id and c.position > ^card.position and c.position <= ^target
    )
    |> Repo.update_all(inc: [position: -1])

    Card.move_changeset(card, %{column_id: card.column_id, position: target})
    |> Repo.update()
  end

  defp cross_column_move(card, dest_column_id, target) do
    from(c in Card, where: c.column_id == ^card.column_id and c.position > ^card.position)
    |> Repo.update_all(inc: [position: -1])

    from(c in Card, where: c.column_id == ^dest_column_id and c.position >= ^target)
    |> Repo.update_all(inc: [position: 1])

    Card.move_changeset(card, %{column_id: dest_column_id, position: target})
    |> Repo.update()
  end
end
