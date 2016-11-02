defmodule Tasvir.Repo.Migrations.CreateText do
  use Ecto.Migration

  def change do
    create table(:texts) do
      add :phone_number, :string
      add :group_id, references(:groups, on_delete: :nothing)

      timestamps()
    end
    create index(:texts, [:group_id])

  end
end
