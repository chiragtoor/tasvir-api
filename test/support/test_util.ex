defmodule Tasvir.TestUtil do

  alias Tasvir.User
  alias Tasvir.Repo
  alias Tasvir.Group

  def get_authorized_conn(conn) do
    user = create_user(random_phone_number)

    build_authorized_conn_for_user(conn, user)
  end

  def build_authorized_conn_for_user(conn, user) do
    jwt = Guardian.Plug.api_sign_in(conn, user)
    |> Guardian.Plug.current_token

    conn
    |> Plug.Conn.put_req_header("authorization", "bearer #{jwt}")
  end

  def create_group do
    group = Group.changeset(%Group{}, %{name: random_string(20)})
    |> Repo.insert!

    group_creator = create_user(random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    user_in_group = create_user(random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    user_not_in_group = create_user(random_phone_number)

    {group, group_creator, user_in_group, user_not_in_group}
  end

  def create_user(phone_number) do
    user_attrs = %{name: random_string(20), 
                   password: random_string(20), 
                   phone_number: phone_number,
                   verification_code: 861718,
                   verification_expiration_time: Calendar.DateTime.now_utc,
                   is_verified: true}

    User.changeset(%User{}, user_attrs)
    |> Repo.insert!
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> :base64.encode
    |> binary_part(0, length)
    |> to_string
  end

  def random_phone_number do
    random_number
    |> to_string
  end

  defp random_number do
    :random.seed(:os.timestamp)
    1000000000 + :random.uniform(8999999999)
  end
end