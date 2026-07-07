defmodule Riftboard.Seeds do
  @moduledoc """
  Demo data for the public Riftboard instance. Wipes all boards and
  re-inserts a fixed demo board; see Riftboard.Application for when this
  runs and RESET_DEMO_DATA_ON_BOOT for how it's gated.
  """

  alias Riftboard.Boards
  alias Riftboard.Boards.Board
  alias Riftboard.Repo

  def reset do
    Repo.delete_all(Board)
    insert_demo_board()
    :ok
  end

  defp insert_demo_board do
    {:ok, board} = Boards.create_board(Board.changeset(%Board{}, %{"name" => "Riftboard Demo"}))
    [todo] = board.columns

    {:ok, in_progress} = Boards.create_column_for_board(board, %{"name" => "In Progress"})
    {:ok, done} = Boards.create_column_for_board(board, %{"name" => "Done"})

    Boards.create_card_for_column(todo, %{
      "title" => "Try dragging a card",
      "description" => "Cards can be reordered within a column or moved across columns."
    })

    Boards.create_card_for_column(todo, %{
      "title" => "Add your own card",
      "description" => "Use \"Add card\" in any column to create one."
    })

    Boards.create_card_for_column(in_progress, %{
      "title" => "This demo resets automatically",
      "description" => "Data here resets whenever the app restarts, so feel free to break it."
    })

    Boards.create_card_for_column(done, %{
      "title" => "Welcome to Riftboard",
      "description" => "A lightweight kanban board built with Phoenix LiveView."
    })
  end
end
