defmodule Riftboard.Repo.Migrations.RenameEmailToUsernameOnUsers do
  use Ecto.Migration

  def change do
    rename table(:users), :email, to: :username
    execute "ALTER INDEX users_email_index RENAME TO users_username_index",
            "ALTER INDEX users_username_index RENAME TO users_email_index"
  end
end
