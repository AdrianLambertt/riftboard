defmodule Riftboard.Boards.Card do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cards" do
    field :title, :string
    field :description, :string
    field :position, :integer

    belongs_to :column, Riftboard.Boards.Column

    timestamps(type: :utc_datetime)
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [:title, :description])
    |> validate_required([:title])
  end

  def move_changeset(card, attrs) do
    card
    |> cast(attrs, [:position, :column_id])
    |> validate_required([:position, :column_id])
  end
end
