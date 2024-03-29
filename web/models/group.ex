defmodule Tasvir.Group do
  use Tasvir.Web, :model

  schema "groups" do
    field :name, :string
    has_many :users, Tasvir.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name])
    |> validate_required([:name])
  end
end
