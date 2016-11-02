defmodule Tasvir.Repo.Migrations.CreateShare do
  use Ecto.Migration

  def change do
    create table(:shares) do
      add :user_id, references(:users, on_delete: :nothing)
      add :photo_id, references(:photos, on_delete: :nothing)
      add :acknowledged, :boolean

      timestamps()
    end
    create index(:shares, [:user_id])
    create index(:shares, [:photo_id])

  end
end
