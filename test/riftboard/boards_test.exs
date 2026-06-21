defmodule Riftboard.BoardsTest do
  use Riftboard.DataCase, async: true

  alias Riftboard.Boards
  alias Riftboard.Boards.{Board, Card, Column}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp board_changeset(attrs \\ %{}) do
    Board.changeset(%Board{}, Map.merge(%{"name" => "Test Board"}, attrs))
  end

  defp create_board!(attrs \\ %{}) do
    {:ok, board} = Boards.create_board(board_changeset(attrs))
    board
  end

  defp create_column!(board, attrs \\ %{}) do
    {:ok, col} = Boards.create_column_for_board(board, Map.merge(%{"name" => "Col"}, attrs))
    col
  end

  defp create_card!(column, attrs \\ %{}) do
    {:ok, card} = Boards.create_card_for_column(column, Map.merge(%{"title" => "Card"}, attrs))
    card
  end

  # ---------------------------------------------------------------------------
  # Boards
  # ---------------------------------------------------------------------------

  describe "create_board/1" do
    test "inserts a board and auto-creates a 'To Do' column" do
      assert {:ok, board} = Boards.create_board(board_changeset())
      assert board.name == "Test Board"

      cols = Repo.preload(board, :columns).columns
      assert length(cols) == 1
      assert hd(cols).name == "To Do"
      assert hd(cols).position == 0
    end

    test "returns error changeset when name is missing" do
      cs = Board.changeset(%Board{}, %{})
      assert {:error, changeset} = Boards.create_board(cs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list_boards/0" do
    test "returns all boards" do
      board = create_board!()
      assert Enum.any?(Boards.list_boards(), &(&1.id == board.id))
    end
  end

  describe "list_boards_with_columns/0" do
    test "preloads columns and cards, ordered by inserted_at desc" do
      b1 = create_board!(%{"name" => "Alpha"})
      b2 = create_board!(%{"name" => "Beta"})

      results = Boards.list_boards_with_columns()
      ids = Enum.map(results, & &1.id)
      assert b2.id in ids
      assert b1.id in ids

      result = Enum.find(results, &(&1.id == b1.id))
      assert %Column{} = hd(result.columns)
    end
  end

  describe "get_board/1" do
    test "returns board by id" do
      board = create_board!()
      assert Boards.get_board(board.id).id == board.id
    end

    test "returns nil for unknown id" do
      assert Boards.get_board(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_board_with_columns_and_cards/1" do
    test "preloads columns and cards" do
      board = create_board!()
      col = create_column!(board, %{"name" => "Backlog"})
      create_card!(col, %{"title" => "Task 1"})

      result = Boards.get_board_with_columns_and_cards(board.id)
      col_names = Enum.map(result.columns, & &1.name)
      assert "To Do" in col_names
      assert "Backlog" in col_names

      backlog = Enum.find(result.columns, &(&1.name == "Backlog"))
      assert hd(backlog.cards).title == "Task 1"
    end
  end

  describe "update_board/1" do
    test "updates board name" do
      board = create_board!()
      cs = Board.changeset(board, %{"name" => "Renamed"})
      assert {:ok, updated} = Boards.update_board(cs)
      assert updated.name == "Renamed"
    end
  end

  describe "delete_board/1" do
    test "deletes the board" do
      board = create_board!()
      assert {:ok, _} = Boards.delete_board(board)
      assert Boards.get_board(board.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Columns
  # ---------------------------------------------------------------------------

  describe "create_column_for_board/2" do
    test "assigns ascending positions" do
      board = create_board!()
      # board already has 'To Do' at position 0
      {:ok, col1} = Boards.create_column_for_board(board, %{"name" => "In Progress"})
      {:ok, col2} = Boards.create_column_for_board(board, %{"name" => "Done"})

      assert col1.position == 1
      assert col2.position == 2
    end

    test "returns error when name is missing" do
      board = create_board!()
      assert {:error, changeset} = Boards.create_column_for_board(board, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_column/1" do
    test "returns column by id" do
      board = create_board!()
      col = create_column!(board)
      assert Boards.get_column(col.id).id == col.id
    end
  end

  describe "delete_column/1" do
    test "deletes the column" do
      board = create_board!()
      col = create_column!(board)
      assert {:ok, _} = Boards.delete_column(col)
      assert Boards.get_column(col.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Cards
  # ---------------------------------------------------------------------------

  describe "create_card_for_column/2" do
    test "assigns ascending positions within the column" do
      board = create_board!()
      col = create_column!(board)

      {:ok, c1} = Boards.create_card_for_column(col, %{"title" => "First"})
      {:ok, c2} = Boards.create_card_for_column(col, %{"title" => "Second"})

      assert c1.position == 0
      assert c2.position == 1
    end

    test "positions are scoped per column" do
      board = create_board!()
      col_a = create_column!(board, %{"name" => "A"})
      col_b = create_column!(board, %{"name" => "B"})

      {:ok, a1} = Boards.create_card_for_column(col_a, %{"title" => "A1"})
      {:ok, b1} = Boards.create_card_for_column(col_b, %{"title" => "B1"})

      assert a1.position == 0
      assert b1.position == 0
    end

    test "returns error when title is missing" do
      board = create_board!()
      col = create_column!(board)
      assert {:error, changeset} = Boards.create_card_for_column(col, %{})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_card/1" do
    test "returns card by id" do
      board = create_board!()
      col = create_column!(board)
      card = create_card!(col)
      assert Boards.get_card(card.id).id == card.id
    end
  end

  describe "update_card/1" do
    test "updates title and description" do
      board = create_board!()
      col = create_column!(board)
      card = create_card!(col, %{"title" => "Original"})

      cs = Card.changeset(card, %{"title" => "Updated", "description" => "Details"})
      assert {:ok, updated} = Boards.update_card(cs)
      assert updated.title == "Updated"
      assert updated.description == "Details"
    end
  end

  describe "delete_card/1" do
    test "deletes the card" do
      board = create_board!()
      col = create_column!(board)
      card = create_card!(col)
      assert {:ok, _} = Boards.delete_card(card)
      assert Boards.get_card(card.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # move_card/3
  # ---------------------------------------------------------------------------

  describe "move_card/3" do
    test "moves card to a new position within the same column, shifting others up" do
      board = create_board!()
      col = create_column!(board)
      c0 = create_card!(col, %{"title" => "C0"})
      c1 = create_card!(col, %{"title" => "C1"})
      c2 = create_card!(col, %{"title" => "C2"})

      # move c2 to position 0 — c0 and c1 should shift up
      assert {:ok, moved} = Boards.move_card(c2, col.id, 0)
      assert moved.position == 0

      assert Boards.get_card(c0.id).position == 1
      assert Boards.get_card(c1.id).position == 2
    end

    test "moves card to a different column" do
      board = create_board!()
      col_a = create_column!(board, %{"name" => "A"})
      col_b = create_column!(board, %{"name" => "B"})

      card = create_card!(col_a, %{"title" => "Traveller"})
      b0 = create_card!(col_b, %{"title" => "B0"})

      assert {:ok, moved} = Boards.move_card(card, col_b.id, 0)
      assert moved.column_id == col_b.id
      assert moved.position == 0

      assert Boards.get_card(b0.id).position == 1
    end

    test "does not shift the card being moved when it is already in the target column" do
      board = create_board!()
      col = create_column!(board)
      c0 = create_card!(col, %{"title" => "C0"})
      c1 = create_card!(col, %{"title" => "C1"})

      assert {:ok, moved} = Boards.move_card(c1, col.id, 1)
      assert moved.position == 1
      assert Boards.get_card(c0.id).position == 0
    end
  end
end
