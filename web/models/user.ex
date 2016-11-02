defmodule Tasvir.User do
  use Tasvir.Web, :model

  alias Tasvir.Repo

  schema "users" do
    field :name, :string
    field :phone_number, :string
    field :password, :string
    field :is_verified, :boolean, default: false
    field :verification_code, :integer
    field :verification_expiration_time, Calecto.DateTimeUTC
    belongs_to :group, Tasvir.Group, [on_replace: :nilify]

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :phone_number, :password, :is_verified,
                     :verification_code, :verification_expiration_time])
    |> cast_assoc(:group, required: false)
    |> validate_required([:name, :phone_number, :password, :is_verified,
                          :verification_code, :verification_expiration_time])
    |> unique_constraint(:phone_number)
  end

  def add_to_group_changeset(user, group) do
    user
    |> Repo.preload(:group)
    |> cast(%{}, [:name, :phone_number, :password, :is_verified,
                     :verification_code, :verification_expiration_time])
    |> put_assoc(:group, group)
  end

  def leave_group_changeset(user) do
    user
    |> Repo.preload(:group)
    |> cast(%{}, [:name, :phone_number, :password, :is_verified,
                     :verification_code, :verification_expiration_time])
    |> put_assoc(:group, nil)
  end

  def register(user_params = %{"password" => password}) do
    changeset_params = user_params
    |> Map.put("password", hash_password(password))
    |> Map.put("is_verified", false)
    |> Map.put("verification_code", random_verification_code())
    |> Map.put("verification_expiration_time", get_verification_limit())

    changeset(%__MODULE__{}, changeset_params)
  end

  def register(user_params) do
    changeset(%__MODULE__{}, user_params)
  end

  def get_user_from_phone_number(phone_number) do
    __MODULE__
    |> where([u], u.phone_number == ^phone_number)
    |> Repo.one
  end

  def check_verification(user, verification_code) do
    case {user.verification_code == verification_code, Calendar.DateTime.after?(user.verification_expiration_time, Calendar.DateTime.now_utc)} do
      {true, true} ->
        {:ok, user}
      {false, true} ->
        {:error, "Incorrect verification code"}
      _ ->
        {:error, "Verification expired"}
    end
  end

  def login(user, password) do
    is_verified = user.is_verified

    case verify_credentials(user, password) do
      true when is_verified ->
        {:ok, user}
      true when not is_verified ->
        {:error}
      false ->
        {:error}
    end
  end

  defp verify_credentials(user, password) do
    Comeonin.Bcrypt.checkpw password, user.password
  end

  defp hash_password(password) do
    Comeonin.Bcrypt.hashpwsalt(password)
  end

  defp random_verification_code do
    :random.seed(:os.timestamp)
    100000 + :random.uniform(899999)
  end

  defp get_verification_limit do
    Calendar.DateTime.now_utc
    |> Calendar.DateTime.add!(300)
  end
end
