defmodule Tasvir.PhotoController do
  use Tasvir.Web, :controller

  import Ecto.Changeset

  alias Tasvir.Photo
  alias Tasvir.Share

  alias Tasvir.S3
  alias Tasvir.Crypto

  plug Guardian.Plug.VerifyHeader, realm: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated, handler: __MODULE__
  plug Guardian.Plug.LoadResource

  # all endpoints in this controller require a logged in user
  # handles management of sharing and retreiving photos

  # called if ever unable to authenticate a user
  def unauthenticated(conn, _params) do
    conn
    |> put_status(401)
    |> json(%{success: 0})
  end

  # when a user creates a photo, a record is created in the DB, the file is uploaded to S3
  #  with the file name (format: [user_id]-[group_id]-[timestamp]), a share record
  #  is created for every user in the group, and the photo id is broadcast to the group
  def create(conn, %{"photo" => upload}) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # load the users group
        user = user
        |> Repo.preload(:group)
        # ensure the user is in a group
        case user.group do
          nil ->
            # no group, error case
            unauthenticated(conn, nil)
          group ->
            # get the unix timestamp, used for file name
            timestamp = Calendar.DateTime.now_utc 
            |> Calendar.DateTime.Format.unix
            # create a formatted filename with the user, group, and timetamp info
            key = "#{user.id}-#{group.id}-#{timestamp}"
            # save the photo to the DB
            photo = Photo.changeset(%Photo{}, user.group, %{"key" => key})
            |> Repo.insert!
            # upload the image to S3
            S3.upload(key, upload.path)
            # load all group members
            group = group
            |> Repo.preload(:users)
            # create a share record for each user in the group
            group.users
            |> Enum.map(fn(group_user) ->
              Share.changeset(%Share{}, group_user, photo)
              |> Repo.insert!
            end)
            # broadcast the new photo id to the group channel
            Tasvir.Endpoint.broadcast("group:#{Crypto.encrypt(group.id)}", "new:msg", %{photo: Crypto.encrypt(photo.id)})
            # return success
            conn
            |> put_status(:created)
            |> json(%{success: 1})
        end
    end
  end

  # used to retreive a photo by the encrypted id, ensures that the user
  #  is allowed to get the photo by checking for a share record
  def show(conn, %{"id" => id}) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # get the photo record corresponding to the id
        case Repo.get!(Photo, Crypto.decrypt(id)) do
          nil ->
            # no photo record, error case
            unauthenticated(conn, nil)
          photo ->
            # get the share record for this user and photo
            share = Share
            |> where(user_id: ^user.id)
            |> where(photo_id: ^photo.id)
            |> Repo.one
            # ensure we have a share record
            case share do
              nil ->
                # no share record for this photo and user, error case
                unauthenticated(conn, nil)
              share ->
                # share record exists, update it to acknowledged
                share
                |> change(acknowledged: true)
                |> Repo.update!
                # download the photo
                photo_download = S3.download(photo.key)
                # use the encrypted id as the filename
                filename = "/tmp/#{Crypto.encrypt(photo.id)}"
                # write the image to a file
                File.write!(filename, photo_download, [:binary])
                # send the file in the request response
                conn
                |> put_resp_content_type("image/jpeg")
                |> put_resp_header("content-disposition", "attachment; filename=#{filename}")
                |> send_file(201, filename)
            end
        end
    end
  end
end
