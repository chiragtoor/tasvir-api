defmodule Tasvir.Text do
  use Tasvir.Web, :model

  alias Tasvir.Repo

  schema "texts" do
    field :phone_number, :string
    belongs_to :group, Tasvir.Group

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, group, params \\ %{}) do
    struct
    |> cast(params, [:phone_number])
    |> validate_required([:phone_number])
    |> put_assoc(:group, group)
  end

  def get_text(group, phone_number) do
    __MODULE__
    |> where([t], t.phone_number == ^phone_number)
    |> where([t], t.group_id == ^group.id)
    |> Repo.one
  end
end
