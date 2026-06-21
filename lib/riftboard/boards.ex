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
    Repo.transact(fn ->
      with {:ok, board} <- Repo.insert(changeset),
           {:ok, _col} <- create_column_for_board(board, %{"name" => "To Do"}) do
        {:ok, board}
      end
    end)
  end

  def update_board(changeset) do
    Repo.update(changeset)
  end

  def delete_board(board) do
    Repo.delete(board)
  end

  # ---------------------------------------------------------------------------
  # Columns
  # ---------------------------------------------------------------------------

  def get_column(id), do: Repo.get(Column, id)

  def create_column_for_board(%Board{id: board_id}, attrs) do
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
    Repo.delete(column)
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

    %Card{}
    |> Card.changeset(attrs)
    |> Ecto.Changeset.put_change(:position, next_pos)
    |> Ecto.Changeset.put_change(:column_id, column_id)
    |> Repo.insert()
  end

  def create_card(changeset) do
    Repo.insert(changeset)
  end

  def update_card(changeset) do
    Repo.update(changeset)
  end

  def delete_card(card) do
    Repo.delete(card)
  end

  def move_card(card, column_id, position) do
    Repo.transact(fn ->
      from(c in Card,
        where: c.position >= ^position and c.column_id == ^column_id and c.id != ^card.id,
        order_by: [asc: c.position]
      )
      |> Repo.all()
      |> Enum.each(&(Card.move_changeset(&1, %{position: &1.position + 1}) |> Repo.update!()))

      # use of update! due to enum.each swallowing return - would ignore individual failure otherwise

      Card.move_changeset(card, %{column_id: column_id, position: position})
      |> Repo.update()
    end)
  end
end
