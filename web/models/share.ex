defmodule Tasvir.Share do
  use Tasvir.Web, :model

  schema "shares" do
    field :acknowledged, :boolean
    belongs_to :user, Tasvir.User
    belongs_to :photo, Tasvir.Photo

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [])
    |> validate_required([])
  end

  def changeset(struct, user, photo, params \\ %{}) do
    struct
    |> cast(params, [])
    |> put_assoc(:user, user)
    |> put_assoc(:photo, photo)
  end
end
