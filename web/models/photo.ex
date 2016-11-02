defmodule Tasvir.Photo do
  use Tasvir.Web, :model

  schema "photos" do
    field :key, :string
    belongs_to :group, Tasvir.Group

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, group, params \\ %{}) do
    struct
    |> cast(params, [:key])
    |> validate_required([:key])
    |> put_assoc(:group, group)
  end
end
