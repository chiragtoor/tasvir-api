defmodule Tasvir.Repo.Migrations.CreatePhoto do
  use Ecto.Migration

  def change do
    create table(:photos) do
      add :key, :string
      add :group_id, references(:groups, on_delete: :nothing)

      timestamps()
    end
    create index(:photos, [:group_id])

  end
end
