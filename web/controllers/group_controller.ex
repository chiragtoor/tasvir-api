defmodule Tasvir.GroupController do
  use Tasvir.Web, :controller

  import Ecto.Changeset

  alias Tasvir.User
  alias Tasvir.Group
  alias Tasvir.Invite
  alias Tasvir.Text

  alias Tasvir.Twilio
  alias Tasvir.Crypto

  plug Guardian.Plug.VerifyHeader, realm: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated, handler: __MODULE__
  plug Guardian.Plug.LoadResource

  # all endpoints in this controller require a logged in user
  # handles all management of groups: create a group, invite members
  #  to a group (update), accept a invite (accept), and leave a group (leave)
  # cannot remove other users from a group, only the user themselves can
  #  opt to leave
  # no admin capabilities for a group

  # called if ever unable to authenticate a user
  def unauthenticated(conn, _) do
    conn
    |> put_status(401)
    |> json(%{success: 0})
  end

  # create a group, only required to have the group name in params
  #  invite_list is optional
  def create(conn, %{"group" => group_params}) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # create a group with the params
        changeset = Group.changeset(%Group{}, group_params)
        # insert the new group into the DB
        case Repo.insert(changeset) do
          {:ok, group} ->
            # update the group creator to be in the group
            user
            |> User.add_to_group_changeset(group)
            |> Repo.update!
            # check if a invite_list was passed
            case Map.get(group_params, "invite_list") do
              nil ->
                # no list, do nothing
                nil
              invite_list ->
                # invite_list exits
                invite_list
                |> Enum.map(fn(phone_number) ->
                  # for each invited phone_number, check if a user exists
                  case User.get_user_from_phone_number(phone_number) do
                    nil ->
                      # no user, send the phone_number a text invite
                      Twilio.send_group_link(conn, phone_number, group.id)
                      # record text record for this number and group
                      Text.changeset(%Text{}, group, %{phone_number: phone_number})
                      |> Repo.insert!
                    user ->
                      # user exists, create a invite record
                      Invite.changeset(%Invite{}, user, group)
                      |> Repo.insert!
                  end
                end)
            end
            # return success
            conn
            |> put_status(:created)
            |> json(%{success: 1})
          {:error, changeset} ->
            # error creating group, return errors
            conn
            |> put_status(:unprocessable_entity)
            |> render(Tasvir.ChangesetView, "error.json", changeset: changeset)
        end
    end
  end

  # update the invite_list for a group to add more members
  def update(conn, %{"id" => id, "group" => %{"invite_list" => invite_list}}) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # load the group for the user
        user = user
        |> Repo.preload(:group)
        # get the group by the encrypted id
        case Repo.get!(Group, Crypto.decrypt(id)) do 
          nil ->
            # no group, error case
            unauthenticated(conn, nil)
          group ->
            case user.group do
              nil ->
                # user not in any group, error case
                unauthenticated(conn, nil)
              user_group ->
                # ensure the user is currently in the group
                if user_group.id == group.id do
                  # go through the new invite_list
                  invite_list
                  |> Enum.map(fn(phone_number) ->
                    # for each invited phone_number, check if a user exists
                    case User.get_user_from_phone_number(phone_number) do
                      nil ->
                        case Text.get_text(group, phone_number) do
                          nil ->
                            # no user, send the phone_number a text invite
                            Twilio.send_group_link(conn, phone_number, group.id)
                            # record text record for this number and group
                            Text.changeset(%Text{}, group, %{phone_number: phone_number})
                            |> Repo.insert!
                          _ ->
                            # phone number was already texted this group
                            nil
                        end
                      user ->
                        # user exists, create a invite record
                        Invite.changeset(%Invite{}, user, group)
                        |> Repo.insert!
                    end
                  end)
                  # return success
                  conn
                  |> put_status(200)
                  |> json(%{success: 1})
                else
                  # user is not in the group, error case
                  unauthenticated(conn, nil)
                end
            end
        end
    end
  end

  # accept a invite for the group
  def accept(conn, %{"id" => id}) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # get the group by the encrypted id
        case Repo.get!(Group, Crypto.decrypt(id)) do 
          nil ->
            # no group, error case
            unauthenticated(conn, nil)
          group ->
            # get the invite record for this user and group
            invite = Invite
            |> where(user_id: ^user.id)
            |> where(group_id: ^group.id)
            |> Repo.one
            # ensure invite record exists
            case invite do
              nil ->
                # no invite record, error case
                unauthenticated(conn, nil)
              invite ->
                invite
                |> change(acknowledged: true)
                |> Repo.update!
                # user was invited to the group, update them to be in it
                user
                |> User.add_to_group_changeset(group)
                |> Repo.update!
                # return success
                conn
                |> put_status(200)
                |> json(%{success: 1})
            end
        end
    end
  end

  # leave the current group
  def leave(conn, _) do
    # ensure we have a authenticated user
    case Guardian.Plug.current_resource(conn) do
      nil ->
        # no user, error case
        unauthenticated(conn, nil)
      user ->
        # take the user out of the current group
        user
        |> User.leave_group_changeset
        |> Repo.update!
        # return success
        conn
        |> put_status(200)
        |> json(%{success: 1})
    end
  end
end
