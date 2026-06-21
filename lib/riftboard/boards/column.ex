defmodule Riftboard.Boards.Column do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "columns" do
    field :name, :string
    field :position, :integer

    belongs_to :board, Riftboard.Boards.Board
    has_many :cards, Riftboard.Boards.Card, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(column, attrs) do
    column
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
