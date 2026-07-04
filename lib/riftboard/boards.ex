defmodule Riftboard.Boards do
  @moduledoc "Context for managing boards, columns, and cards."

  import Ecto.Query
  alias Riftboard.Boards.{Board, Card, Column}
  alias Riftboard.Repo

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
             {:ok, _col} <- create_column_for_board(board, %{"name" => "To Do"}) do
          {:ok, Repo.preload(board, columns: :cards)}
        end
      end)

    broadcast_board_change(result, :add)
    result
  end

  def update_board(changeset) do
    result = Repo.update(changeset)
    broadcast_board_change(result, :update)
    result
  end

  def delete_board(board) do
    result = Repo.delete(board)
    broadcast_board_change(result, :delete)
    result
  end

  def broadcast_board_change({:error, _board}, _) do
    :pass
  end

  def broadcast_board_change({:ok, board}, action) when action in [:add, :update, :delete] do
    Phoenix.PubSub.broadcast(Riftboard.PubSub, "board_updates", {:board_updates, {board, action}})
  end

  # ---------------------------------------------------------------------------
  # Columns
  # ---------------------------------------------------------------------------

  def get_column(id), do: Repo.get(Column, id)

  def create_column_for_board(%Board{id: board_id} = board, attrs) do
    next_pos =
      from(c in Column, where: c.board_id == ^board_id, select: max(c.position))
      |> Repo.one()
      |> case do
        nil -> 0
        pos -> pos + 1
      end

    {status, result} =
      %Column{}
      |> Column.changeset(attrs)
      |> Ecto.Changeset.put_change(:position, next_pos)
      |> Ecto.Changeset.put_change(:board_id, board_id)
      |> Repo.insert()

    board = Repo.preload(board, [columns: :cards], force: true)
    broadcast_board_change({status, board}, :update)

    {status, result}
  end

  def create_column(changeset) do
    Repo.insert(changeset)
  end

  def update_column(changeset) do
    Repo.update(changeset)
  end

  def delete_column(column) do
    {status, result} = Repo.delete(column)
    board = Repo.get(Board, column.board_id) |> Repo.preload([columns: :cards], force: true)
    broadcast_board_change({status, board}, :update)
    {status, result}
  end

  # ---------------------------------------------------------------------------
  # Cards
  # ---------------------------------------------------------------------------

  def get_card(id), do: Repo.get(Card, id)

  def create_card_for_column(%Column{id: column_id}, attrs) do
    next_pos =
      from(c in Card, where: c.column_id == ^column_id, select: max(c.position))
      |> Repo.one()
      |> case do
        nil -> 0
        pos -> pos + 1
      end

    {status, result} =
      %Card{}
      |> Card.changeset(attrs)
      |> Ecto.Changeset.put_change(:position, next_pos)
      |> Ecto.Changeset.put_change(:column_id, column_id)
      |> Repo.insert()

    board =
      from(b in Board,
        join: col in Column,
        on: col.board_id == b.id,
        where: col.id == ^column_id,
        select: b
      )
      |> Repo.one()

    board = Repo.preload(board, [columns: :cards], force: true)
    broadcast_board_change({status, board}, :update)

    {status, result}
  end

  def create_card(changeset) do
    Repo.insert(changeset)
  end

  def update_card(changeset) do
    Repo.update(changeset)
  end

  def delete_card(card) do
    {status, result} = Repo.delete(card)
    column = Repo.get(Column, card.column_id)
    board = Repo.get(Board, column.board_id) |> Repo.preload([columns: :cards], force: true)
    broadcast_board_change({status, board}, :update)
    {status, result}
  end

  def move_card(card, column_id, position) do
    Repo.transact(fn ->
      if card.column_id == column_id do
        same_column_move(card, position)
      else
        cross_column_move(card, column_id, position)
      end
    end)
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
