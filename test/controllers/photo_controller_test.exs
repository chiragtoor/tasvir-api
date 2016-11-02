defmodule Tasvir.PhotoControllerTest do
  use Tasvir.ConnCase

  alias Tasvir.TestUtil

  alias Tasvir.Photo
  alias Tasvir.Share

  alias Tasvir.Crypto
  alias Tasvir.S3

  @test_file "test/fixtures/test.jpg"
  @test_file_size 2088527

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp clear_bucket do
    bucket = Application.get_env(:tasvir, Tasvir.Endpoint)[:bucket]

    %{body: %{contents: objects}} = bucket
    |> ExAws.S3.list_objects!
    |> ExAws.S3.Parsers.parse_list_objects

    objects
    |> Enum.map(fn(%{key: object_key}) ->
      ExAws.S3.delete_object!(bucket, object_key)
    end)
  end

  test "can create a photo", %{conn: conn} do
    {_, group_creator, _, _} = TestUtil.create_group

    upload = %Plug.Upload{path: @test_file, filename: "test.png"}

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    conn = post conn, "/api/photos", photo: upload

    body = json_response(conn, 201)
    assert 1 == body["success"], "unable to update group"
    
    clear_bucket
  end

  test "creating a photo creates a share record for everyone in the group", %{conn: conn} do
    {group, group_creator, user_in_group, _} = TestUtil.create_group

    upload = %Plug.Upload{path: @test_file, filename: "test.png"}

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    post conn, "/api/photos", photo: upload

    photo = Photo
    |> where(group_id: ^group.id)
    |> Repo.one

    share = Share
    |> where(user_id: ^user_in_group.id)
    |> where(photo_id: ^photo.id)
    |> Repo.one

    assert share != nil, "no share record for user_in_group"
    
    clear_bucket
  end

  test "creating a photo does not create a share record with group invites not in group", %{conn: conn} do
    {group, group_creator, _, user_not_in_group} = TestUtil.create_group

    upload = %Plug.Upload{path: @test_file, filename: "test.png"}

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    post conn, "/api/photos", photo: upload

    photo = Photo
    |> where(group_id: ^group.id)
    |> Repo.one

    share = Share
    |> where(user_id: ^user_not_in_group.id)
    |> where(photo_id: ^photo.id)
    |> Repo.one

    assert share == nil, "share record for user_not_in_group"
    
    clear_bucket
  end

  test "photo record keys are formatted with user id, group id, timestamp", %{conn: conn} do
    {group, group_creator, _, _} = TestUtil.create_group

    upload = %Plug.Upload{path: @test_file, filename: "test.png"}

    conn = TestUtil.build_authorized_conn_for_user(conn, group_creator)

    timestamp = Calendar.DateTime.now_utc 
    |> Calendar.DateTime.Format.unix

    post conn, "/api/photos", photo: upload

    photo = Photo
    |> where(group_id: ^group.id)
    |> Repo.one

    assert photo.key == "#{group_creator.id}-#{group.id}-#{timestamp}", "incorrect format for photo record key"

    clear_bucket
  end

  test "can retreive a photo", %{conn: conn} do
    {group, group_creator, user_in_group, _} = TestUtil.create_group

    conn = TestUtil.build_authorized_conn_for_user(conn, user_in_group)

    timestamp = Calendar.DateTime.now_utc 
    |> Calendar.DateTime.Format.unix

    key = "#{group_creator.id}-#{group.id}-#{timestamp}"

    S3.upload(key, @test_file)

    photo = Photo.changeset(%Photo{}, group, %{"key" => key})
    |> Repo.insert!

    Share.changeset(%Share{}, user_in_group, photo)
    |> Repo.insert!

    conn = get conn, "/api/photos/#{Crypto.encrypt(photo.id)}"

    %Plug.Conn{status: status, resp_body: body} = conn

    assert status == 201, "could not retrive photo"
    assert byte_size(body) == @test_file_size, "retrieved photo is incorrect size"

    clear_bucket
  end

  test "cannot retreive a photo if there is no share record", %{conn: conn} do
    {group, group_creator, user_in_group, _} = TestUtil.create_group

    conn = TestUtil.build_authorized_conn_for_user(conn, user_in_group)

    timestamp = Calendar.DateTime.now_utc 
    |> Calendar.DateTime.Format.unix

    key = "#{group_creator.id}-#{group.id}-#{timestamp}"

    S3.upload(key, @test_file)

    photo = Photo.changeset(%Photo{}, group, %{"key" => key})
    |> Repo.insert!

    conn = get conn, "/api/photos/#{Crypto.encrypt(photo.id)}"

    body = json_response(conn, 401)
    assert 0 == body["success"], "incorrectly got success for unretreived photo"

    clear_bucket
  end

  test "retreiving a photo marks the share record as acknowledged", %{conn: conn} do
    {group, group_creator, user_in_group, _} = TestUtil.create_group

    conn = TestUtil.build_authorized_conn_for_user(conn, user_in_group)

    timestamp = Calendar.DateTime.now_utc 
    |> Calendar.DateTime.Format.unix

    key = "#{group_creator.id}-#{group.id}-#{timestamp}"

    S3.upload(key, @test_file)

    photo = Photo.changeset(%Photo{}, group, %{"key" => key})
    |> Repo.insert!

    Share.changeset(%Share{}, user_in_group, photo)
    |> Repo.insert!

    get conn, "/api/photos/#{Crypto.encrypt(photo.id)}"

    share = Share
    |> where(user_id: ^user_in_group.id)
    |> where(photo_id: ^photo.id)
    |> Repo.one

    assert share.acknowledged == true, "share record not marked acknowledged after photo retreived"

    clear_bucket
  end
end
