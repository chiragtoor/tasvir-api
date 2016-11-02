defmodule Tasvir.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :phone_number, :string
      add :password, :string
      add :is_verified, :boolean, default: false, null: false
      add :verification_code, :integer
      add :verification_expiration_time, :datetime
      add :group_id, references(:groups, on_delete: :nothing)

      timestamps()
    end
    create index(:users, [:group_id])
    create unique_index(:users, [:phone_number])

  end
end
