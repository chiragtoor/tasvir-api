defmodule Tasvir.UserController do
  use Tasvir.Web, :controller

  import Ecto.Changeset

  alias Tasvir.User

  # create a user, phone_number is unique
  def create(conn, %{"user" => user_params}) do
    changeset = User.register(user_params)
    # insert the user into the DB
    case Repo.insert(changeset) do
      {:ok, user} ->
        # new user created, send a verification code that must be returned
        #  within 5 minutes to complete account create process
        Tasvir.Twilio.send_verification_code(conn, user)
        # return success
        conn
        |> put_status(:created)
        |> json(%{success: 1})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(Tasvir.ChangesetView, "error.json", changeset: changeset)
    end
  end

  # take in a phone number and code and verify a new users account
  def verify(conn, %{"phone_number" => phone_number, "verification_code" => verification_code}) do
    # get the user account for the phone number
    case User.get_user_from_phone_number(phone_number) do
      nil ->
        # no account, error case
        conn
        |> put_status(400)
        |> json(%{success: 0})
      user ->
        # check that the user's code is correct and within time limit
        case User.check_verification(user, verification_code) do
          {:ok, user} ->
            # set the user as verified in the DB
            user = change(user, is_verified: true)
            |> Repo.update!
            # send the authentication token back in the response
            new_conn = Guardian.Plug.api_sign_in(conn, user)
            jwt = Guardian.Plug.current_token(new_conn)
            {:ok, claims} = Guardian.Plug.claims(new_conn)
            exp = Map.get(claims, "exp")
            # respond success with token
            new_conn
            |> put_resp_header("authorization", "bearer #{jwt}")
            |> put_resp_header("x-expires", "#{exp}")
            |> json(%{success: 1})
          {:error, _} ->
            conn
            |> put_status(400)
            |> json(%{success: 0})
        end
    end
  end

  # login a existing user to get a new authentication token
  def login(conn, %{"phone_number" => phone_number, "password" => password}) do
    # get the user for the given phone number
    case User.get_user_from_phone_number(phone_number) do
      nil ->
        # no user, error case
        conn
        |> put_status(400)
        |> json(%{success: 0})
      user ->
        # login the user and ensure the password matches, and the user is verified
        case User.login(user, password) do
          {:ok, user} ->
            # generate a new authentication token
            new_conn = Guardian.Plug.api_sign_in(conn, user)
            jwt = Guardian.Plug.current_token(new_conn)
            {:ok, claims} = Guardian.Plug.claims(new_conn)
            exp = Map.get(claims, "exp")
            # respond success with new token
            new_conn
            |> put_resp_header("authorization", "bearer #{jwt}")
            |> put_resp_header("x-expires", "#{exp}")
            |> json(%{success: 1})
          {:error} ->
            conn
            |> put_status(400)
            |> json(%{success: 0})
        end
    end
  end
end
