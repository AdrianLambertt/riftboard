defmodule RiftboardWeb.BoardLive.IndexTest do
  use RiftboardWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Riftboard.Boards
  alias Riftboard.Boards.Board

  defp create_board!(attrs \\ %{}) do
    {:ok, board} =
      Boards.create_board(Board.changeset(%Board{}, Map.merge(%{"name" => "Test Board"}, attrs)))

    board
  end

  # ---------------------------------------------------------------------------
  # mount
  # ---------------------------------------------------------------------------

  describe "mount" do
    test "renders board list page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/boards")
      assert html =~ "Boards"
      assert html =~ "New Board"
    end

    test "shows empty state when there are no boards", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/boards")
      assert html =~ "No boards yet"
    end

    test "lists existing boards", %{conn: conn} do
      create_board!(%{"name" => "My Project"})
      {:ok, _lv, html} = live(conn, ~p"/boards")
      assert html =~ "My Project"
    end

    test "shows column names and card counts for each board", %{conn: conn} do
      board = create_board!(%{"name" => "Board With Columns"})
      # board auto-creates a "To Do" column; add a card to it
      [todo_col] = Riftboard.Repo.preload(board, :columns).columns
      {:ok, _} = Boards.create_card_for_column(todo_col, %{"title" => "Task 1"})

      {:ok, _lv, html} = live(conn, ~p"/boards")
      assert html =~ "To Do"
      # card count 1 should appear somewhere on the page
      assert html =~ "1"
    end
  end

  # ---------------------------------------------------------------------------
  # new board modal
  # ---------------------------------------------------------------------------

  describe "new board modal" do
    test "opens when navigating to /boards/new", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/boards/new")
      assert html =~ "New Board"
      assert html =~ "Create Board"
    end

    test "validate event shows error for blank name", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/boards/new")

      html =
        lv
        |> form("#new-board-modal form", board: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "save with valid name creates board and navigates to show", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/boards/new")

      assert {:ok, _show_lv, show_html} =
               lv
               |> form("#new-board-modal form", board: %{name: "Sprint 1"})
               |> render_submit()
               |> follow_redirect(conn)

      assert show_html =~ "Sprint 1"
    end

    test "save with blank name shows validation error and stays on modal", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/boards/new")

      html =
        lv
        |> form("#new-board-modal form", board: %{name: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  # ---------------------------------------------------------------------------
  # delete board
  # ---------------------------------------------------------------------------

  describe "delete_board event" do
    test "removes the board from the list", %{conn: conn} do
      board = create_board!(%{"name" => "Doomed Board"})
      {:ok, lv, _html} = live(conn, ~p"/boards")

      assert render(lv) =~ "Doomed Board"

      lv
      |> element("button[phx-value-id='#{board.id}']")
      |> render_click()

      refute render(lv) =~ "Doomed Board"
    end

    test "deletes the board from the database", %{conn: conn} do
      board = create_board!(%{"name" => "Gone Board"})
      {:ok, lv, _html} = live(conn, ~p"/boards")

      lv
      |> element("button[phx-value-id='#{board.id}']")
      |> render_click()

      assert Boards.get_board(board.id) == nil
    end
  end
end
