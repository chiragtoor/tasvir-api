defmodule Tasvir.Repo.Migrations.CreateInvite do
  use Ecto.Migration

  def change do
    create table(:invites) do
      add :user_id, references(:users, on_delete: :nothing)
      add :group_id, references(:groups, on_delete: :nothing)
      add :acknowledged, :boolean, default: false, null: false

      timestamps()
    end
    create index(:invites, [:user_id])
    create index(:invites, [:group_id])

  end
end
