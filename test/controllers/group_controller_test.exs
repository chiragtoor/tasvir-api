defmodule Tasvir.GroupControllerTest do
  use Tasvir.ConnCase

  alias Tasvir.Group
  alias Tasvir.User
  alias Tasvir.Invite
  alias Tasvir.Text

  alias Tasvir.Repo
  alias Tasvir.Crypto

  alias Tasvir.TestUtil

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "must pass a authorization token to create a group", %{conn: conn} do
    group_attrs = %{name: TestUtil.random_string(20)}

    conn = post conn, "/api/groups", group: group_attrs

    body = json_response(conn, 401)
    assert 0 == body["success"], "incorrectly got success response"
  end

  test "can create a group", %{conn: conn} do
    conn = TestUtil.get_authorized_conn(conn)

    group_attrs = %{name: TestUtil.random_string(20)}

    conn = post conn, "/api/groups", group: group_attrs

    body = json_response(conn, 201)
    assert 1 == body["success"], "unable to create group"
  end

  test "can create a group with a invite_list", %{conn: conn} do
    conn = TestUtil.get_authorized_conn(conn)

    group_attrs = %{name: TestUtil.random_string(20), invite_list: [TestUtil.random_phone_number, TestUtil.random_phone_number]}

    conn = post conn, "/api/groups", group: group_attrs

    body = json_response(conn, 201)
    assert 1 == body["success"], "unable to create group"
  end

  test "invite records created for users when a group is made", %{conn: conn} do
    conn = TestUtil.get_authorized_conn(conn)

    user_one = TestUtil.create_user(TestUtil.random_phone_number)
    user_two = TestUtil.create_user(TestUtil.random_phone_number)

    group_attrs = %{name: TestUtil.random_string(20), invite_list: [user_one.phone_number, user_two.phone_number]}

    post conn, "/api/groups", group: group_attrs

    group = Group
    |> where(name: ^group_attrs[:name])
    |> Repo.one

    invite_one = Invite
    |> where(user_id: ^user_one.id)
    |> where(group_id: ^group.id)
    |> Repo.one

    assert invite_one != nil, "no invite record for user_one"

    invite_two = Invite
    |> where(user_id: ^user_two.id)
    |> where(group_id: ^group.id)
    |> Repo.one

    assert invite_two != nil, "no invite record for user_two"
  end

  test "text records created when a group is made", %{conn: conn} do
    user = TestUtil.create_user(TestUtil.random_phone_number)

    conn = TestUtil.build_authorized_conn_for_user(conn, user)

    phone_number = TestUtil.random_phone_number

    group_attrs = %{name: TestUtil.random_string(20), invite_list: [phone_number]}

    post conn, "/api/groups", group: group_attrs

    group = Group
    |> where(name: ^group_attrs[:name])
    |> Repo.one

    text = Text
    |> where(group_id: ^group.id)
    |> where(phone_number: ^phone_number)
    |> Repo.one

    assert text != nil, "no text record created for this group and user"
  end

  test "updating a group does not duplicate text records", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    group_creator = TestUtil.create_user(TestUtil.random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    phone_number = TestUtil.random_phone_number

    Text.changeset(%Text{}, group, %{phone_number: phone_number})
    |> Repo.insert!

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    update_attrs = %{invite_list: [phone_number]}

    put conn, "/api/groups/#{Crypto.encrypt(group.id)}", group: update_attrs

    texts = Text
    |> where(group_id: ^group.id)
    |> where(phone_number: ^phone_number)
    |> Repo.all

    assert Enum.count(texts) == 1, "multiple text records created on re-invite of phone number"
  end

  test "can update a group and add new members", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    group_creator = TestUtil.create_user(TestUtil.random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    user_one = TestUtil.create_user(TestUtil.random_phone_number)
    user_two = TestUtil.create_user(TestUtil.random_phone_number)

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    update_attrs = %{invite_list: [user_one.phone_number, user_two.phone_number]}

    conn = put conn, "/api/groups/#{Crypto.encrypt(group.id)}", group: update_attrs

    body = json_response(conn, 200)
    assert 1 == body["success"], "unable to update group"

    invite_one = Invite
    |> where(user_id: ^user_one.id)
    |> where(group_id: ^group.id)
    |> Repo.one

    assert invite_one != nil, "no invite record for user_one"

    invite_two = Invite
    |> where(user_id: ^user_two.id)
    |> where(group_id: ^group.id)
    |> Repo.one

    assert invite_two != nil, "no invite record for user_two"
  end

  test "must be in group to add new members", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    group_creator = TestUtil.create_user(TestUtil.random_phone_number)

    user_one = TestUtil.create_user(TestUtil.random_phone_number)
    user_two = TestUtil.create_user(TestUtil.random_phone_number)

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    update_attrs = %{invite_list: [user_one.phone_number, user_two.phone_number]}

    conn = put conn, "/api/groups/#{Crypto.encrypt(group.id)}", group: update_attrs

    body = json_response(conn, 401)
    assert 0 == body["success"], "incorrectly invited to group without being in it"
  end

  test "must be in correct group to add new members", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    group_creator = TestUtil.create_user(TestUtil.random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    group_update = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    user_one = TestUtil.create_user(TestUtil.random_phone_number)
    user_two = TestUtil.create_user(TestUtil.random_phone_number)

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    update_attrs = %{invite_list: [user_one.phone_number, user_two.phone_number]}

    conn = put conn, "/api/groups/#{Crypto.encrypt(group_update.id)}", group: update_attrs

    body = json_response(conn, 401)
    assert 0 == body["success"], "incorrectly invited to group without being in it"
  end

  test "can accept a invite to a group", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    user = TestUtil.create_user(TestUtil.random_phone_number)

    Invite.changeset(%Invite{}, user, group)
    |> Repo.insert!

    conn = TestUtil.build_authorized_conn_for_user(conn, user)

    conn = post conn, "/api/groups/#{Crypto.encrypt(group.id)}/accept"

    body = json_response(conn, 200)
    assert 1 == body["success"], "unable to accept invite"
  end

  test "cannot accept a invite to a uninvited group", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    user = TestUtil.create_user(TestUtil.random_phone_number)

    conn = TestUtil.build_authorized_conn_for_user(conn, user)

    conn = post conn, "/api/groups/#{Crypto.encrypt(group.id)}/accept"

    body = json_response(conn, 401)
    assert 0 == body["success"], "incorrectly able to accept invite"
  end

  test "accepting a invite marks the invite as accepted", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    user = TestUtil.create_user(TestUtil.random_phone_number)

    Invite.changeset(%Invite{}, user, group)
    |> Repo.insert!

    conn = TestUtil.build_authorized_conn_for_user(conn, user)

    post conn, "/api/groups/#{Crypto.encrypt(group.id)}/accept"

    invite = Invite
    |> where(user_id: ^user.id)
    |> where(group_id: ^group.id)
    |> Repo.one

    assert invite.acknowledged, "on group invite accept the invite was not marked acknowledged"
  end

  test "can leave a group", %{conn: conn} do
    group = Group.changeset(%Group{}, %{name: TestUtil.random_string(20)})
    |> Repo.insert!

    user = TestUtil.create_user(TestUtil.random_phone_number)
    |> User.add_to_group_changeset(group)
    |> Repo.update!

    conn = TestUtil.build_authorized_conn_for_user(conn, user)

    conn = post conn, "/api/groups/leave"

    body = json_response(conn, 200)
    assert 1 == body["success"], "unable to leave group"
  end
end
