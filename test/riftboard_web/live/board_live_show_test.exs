defmodule RiftboardWeb.BoardLive.ShowTest do
  use RiftboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Riftboard.Boards
  alias Riftboard.Boards.Board

  setup :register_and_log_in_user

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_board!(attrs \\ %{}) do
    {:ok, board} =
      Boards.create_board(Board.changeset(%Board{}, Map.merge(%{"name" => "Test Board"}, attrs)))

    board
  end

  defp get_todo_column(board) do
    Riftboard.Repo.preload(board, :columns).columns
    |> Enum.find(&(&1.name == "To Do"))
  end

  defp create_card!(column, attrs) do
    {:ok, card} = Boards.create_card_for_column(column, Map.merge(%{"title" => "A Card"}, attrs))
    card
  end

  # ---------------------------------------------------------------------------
  # mount
  # ---------------------------------------------------------------------------

  describe "mount" do
    test "renders the board name and its columns", %{conn: conn} do
      board = create_board!(%{"name" => "My Board"})
      {:ok, _lv, html} = live(conn, ~p"/boards/#{board.id}")

      assert html =~ "My Board"
      assert html =~ "To Do"
    end

    test "redirects to /boards for an unknown id", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/boards"}}} =
               live(conn, ~p"/boards/#{Ecto.UUID.generate()}")
    end

    test "renders cards within their columns", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      create_card!(col, %{"title" => "Important Task"})

      {:ok, _lv, html} = live(conn, ~p"/boards/#{board.id}")
      assert html =~ "Important Task"
    end
  end

  # ---------------------------------------------------------------------------
  # Columns
  # ---------------------------------------------------------------------------

  describe "add column" do
    test "show_add_column reveals the column form", %{conn: conn} do
      board = create_board!()
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      html =
        lv
        |> element("button[phx-click='show_add_column']")
        |> render_click()

      assert html =~ "Add column"
    end

    test "save_column creates column and shows it on the board", %{conn: conn} do
      board = create_board!()
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("button[phx-click='show_add_column']") |> render_click()

      lv
      |> form("form[phx-submit='save_column']", column: %{name: "In Progress"})
      |> render_submit()

      assert render(lv) =~ "In Progress"
    end

    test "save_column persists to the database", %{conn: conn} do
      board = create_board!()
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("button[phx-click='show_add_column']") |> render_click()
      lv |> form("form[phx-submit='save_column']", column: %{name: "Done"}) |> render_submit()

      col_names =
        Boards.get_board_with_columns_and_cards(board.id).columns
        |> Enum.map(& &1.name)

      assert "Done" in col_names
    end

    test "cancel_add_column hides the form", %{conn: conn} do
      board = create_board!()
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("button[phx-click='show_add_column']") |> render_click()

      html =
        lv
        |> element("button[phx-click='cancel_add_column']")
        |> render_click()

      refute html =~ "Add column"
    end
  end

  describe "delete column" do
    test "removes the column from the board", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv
      |> element("button[phx-click='delete_column'][phx-value-id='#{col.id}']")
      |> render_click()

      refute render(lv) =~ "To Do"
    end

    test "deletes the column from the database", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv
      |> element("button[phx-click='delete_column'][phx-value-id='#{col.id}']")
      |> render_click()

      assert Boards.get_column(col.id) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Cards
  # ---------------------------------------------------------------------------

  describe "add card" do
    test "show_add_card reveals the card form for the right column", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      html =
        lv
        |> element("button[phx-click='show_add_card'][phx-value-column_id='#{col.id}']")
        |> render_click()

      assert html =~ "Card title"
    end

    test "save_card creates card and renders it", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv
      |> element("button[phx-click='show_add_card'][phx-value-column_id='#{col.id}']")
      |> render_click()

      lv
      |> form("form[phx-submit='save_card']", card: %{title: "New Task"})
      |> render_submit()

      assert render(lv) =~ "New Task"
    end

    test "save_card persists to the database", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv
      |> element("button[phx-click='show_add_card'][phx-value-column_id='#{col.id}']")
      |> render_click()

      lv
      |> form("form[phx-submit='save_card']", card: %{title: "Persisted Task"})
      |> render_submit()

      card_titles =
        Boards.get_board_with_columns_and_cards(board.id).columns
        |> Enum.flat_map(& &1.cards)
        |> Enum.map(& &1.title)

      assert "Persisted Task" in card_titles
    end
  end

  describe "card modal" do
    test "open_card shows the edit modal with the card title", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Editable Card"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      html =
        lv
        |> element("#card-#{card.id}")
        |> render_click()

      assert html =~ "Editable Card"
      assert html =~ "Save"
    end

    test "update_card saves the new title", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Old Title"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("#card-#{card.id}") |> render_click()

      lv
      |> form("form[phx-submit='update_card']", card: %{title: "New Title"})
      |> render_submit()

      assert render(lv) =~ "New Title"
      assert Boards.get_card(card.id).title == "New Title"
    end

    test "delete_card removes the card from the board", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Doomed Card"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("#card-#{card.id}") |> render_click()

      lv
      |> element("button[phx-click='delete_card'][phx-value-id='#{card.id}']")
      |> render_click()

      refute render(lv) =~ "Doomed Card"
      assert Boards.get_card(card.id) == nil
    end

    test "close_card dismisses the modal", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Some Card"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      lv |> element("#card-#{card.id}") |> render_click()
      html = lv |> element("button[phx-click='close_card']") |> render_click()

      refute html =~ "Save"
    end
  end

  # ---------------------------------------------------------------------------
  # card_moved
  # ---------------------------------------------------------------------------

  describe "card_moved event" do
    test "updates card position in the database", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      c0 = create_card!(col, %{"title" => "C0"})
      c1 = create_card!(col, %{"title" => "C1"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      render_hook(lv, "card_moved", %{
        "card_id" => c1.id,
        "column_id" => col.id,
        "position" => 0
      })

      assert Boards.get_card(c1.id).position == 0
      assert Boards.get_card(c0.id).position == 1
    end

    test "card_moved across columns updates column_id", %{conn: conn} do
      board = create_board!()
      col_a = get_todo_column(board)
      {:ok, col_b} = Boards.create_column_for_board(board, %{"name" => "Done"})
      card = create_card!(col_a, %{"title" => "Mover"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      render_hook(lv, "card_moved", %{
        "card_id" => card.id,
        "column_id" => col_b.id,
        "position" => 0
      })

      updated = Boards.get_card(card.id)
      assert updated.column_id == col_b.id
      assert updated.position == 0
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub — real-time show-page updates
  # ---------------------------------------------------------------------------

  describe "PubSub" do
    test "reflects a column added from another session", %{conn: conn} do
      board = create_board!(%{"name" => "Multi-Column Board"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      Boards.create_column_for_board(board, %{"name" => "In Review"})

      assert render(lv) =~ "In Review"
    end

    test "removes a column deleted from another session", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")
      assert render(lv) =~ "To Do"

      Boards.delete_column(col)

      refute render(lv) =~ "To Do"
    end

    test "reflects a card added to a column from another session", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      create_card!(col, %{"title" => "Remote Task"})

      assert render(lv) =~ "Remote Task"
    end

    test "reflects a card title updated from another session", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Old Title"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      Boards.update_card(Riftboard.Boards.Card.changeset(card, %{"title" => "New Title"}))

      html = render(lv)
      assert html =~ "New Title"
      refute html =~ "Old Title"
    end

    test "removes a card deleted from another session", %{conn: conn} do
      board = create_board!()
      col = get_todo_column(board)
      card = create_card!(col, %{"title" => "Doomed Card"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")
      assert render(lv) =~ "Doomed Card"

      Boards.delete_card(card)

      refute render(lv) =~ "Doomed Card"
    end

    test "reflects a card moved to another column from another session", %{conn: conn} do
      board = create_board!()
      col_a = get_todo_column(board)
      {:ok, col_b} = Boards.create_column_for_board(board, %{"name" => "Done"})
      card = create_card!(col_a, %{"title" => "Mover"})
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      Boards.move_card(card, col_b.id, 0)

      html = render(lv)
      assert Boards.get_card(card.id).column_id == col_b.id
      assert html =~ "Mover"
    end

    test "redirects with a flash when the board is deleted from another session", %{conn: conn} do
      board = create_board!()
      {:ok, lv, _html} = live(conn, ~p"/boards/#{board.id}")

      Boards.delete_board(board)

      assert_redirect(lv, ~p"/boards")
    end
  end
end
