defmodule Tasvir.Invite do
  use Tasvir.Web, :model

  schema "invites" do
    field :acknowledged, :boolean, default: false
    belongs_to :user, Tasvir.User
    belongs_to :group, Tasvir.Group

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:acknowledged])
    |> cast_assoc(:user, required: true)
    |> cast_assoc(:group, required: true)
  end

  def changeset(struct, user, group) do
    struct
    |> cast(%{}, [])
    |> validate_required([])
    |> put_assoc(:user, user)
    |> put_assoc(:group, group)
  end
end
