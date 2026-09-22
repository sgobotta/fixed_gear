defmodule FixedGear.Repo.Migrations.AddAdminToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :admin, :boolean, null: false, default: false
    end

    # Accounts that already exist were the admin. New users stay false.
    execute("UPDATE users SET admin = true", "UPDATE users SET admin = false")
  end
end
