defmodule Riftboard.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :display_name, :string, null: false, default: ""
      add :color, :string, null: false, default: ""
      add :is_guest, :boolean, null: false, default: false
    end
  end
end
