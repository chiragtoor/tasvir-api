defmodule Tasvir.UserControllerTest do
  use Tasvir.ConnCase

  alias Tasvir.User
  
  alias Tasvir.TestUtil

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "able to create a user", %{conn: conn} do
    verification_time = Calendar.DateTime.now_utc
    |> Calendar.DateTime.add!(300)

    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    body = json_response(conn, 201)

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    assert 1 == body["success"], "unable to create user account"
    assert user != nil
    assert user.name == user_attrs[:name], "name incorrectly stored"
    assert user.is_verified == false, "is_verified not defaulting to false"
    assert user.group_id == nil, "current_group_id not defaulting to nil"
    assert verification_expiration_time_within_limits(verification_time, user.verification_expiration_time), 
      "verification_expiration_time not 5 minutes (+ 3 seconds)"
  end

  test "cannot create user with same phone_number twice", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: user_attrs[:phone_number]}

    conn = post conn, "/api/users", user: user_attrs

    body = json_response(conn, 422)

    assert 0 == body["success"], "incorrectly replied success"
    assert ["has already been taken"] == body["errors"]["phone_number"]
  end

  test "able to verify a user account", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    verify_attrs = %{phone_number: user.phone_number,
                     verification_code: user.verification_code}

    conn = post conn, "/api/verify", verify_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    body = json_response(conn, 200)
    assert 1 == body["success"], "unable to verify account"
    assert user.is_verified, "user record was not updated to verified"
  end

  test "incorrect verification code does not verify a account", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    verify_attrs = %{phone_number: user.phone_number,
                     verification_code: (user.verification_code + 1)}

    conn = post conn, "/api/verify", verify_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    body = json_response(conn, 400)
    assert 0 == body["success"], "incorrect success response"
    assert user.is_verified == false, "user record incorrectly chagned to verified"
  end

  test "cannot pass verification params in create user request", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number,
                   verification_code: 816785,
                   is_verified: 1}

    post conn, "/api/users", user: user_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    assert user.is_verified == false, "user incorrectly set to verified through params"
    assert user.verification_code != 816785, "user verification_code incorrectly set through params"
  end

  test "cannot login unless verified", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    login_params = %{phone_number: user_attrs[:phone_number],
                     password: user_attrs[:password]}

    conn = post conn, "/api/login", login_params

    body = json_response(conn, 400)

    assert 0 == body["success"], "incorrect success response"
  end

  test "can login with correct password after verification", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    verify_attrs = %{phone_number: user.phone_number,
                     verification_code: user.verification_code}

    conn = post conn, "/api/verify", verify_attrs

    login_params = %{phone_number: user_attrs[:phone_number],
                     password: user_attrs[:password]}

    conn = post conn, "/api/login", login_params

    body = json_response(conn, 200)
    assert 1 == body["success"], "unable to login"
  end

  test "cannot login with incorrect password", %{conn: conn} do
    user_attrs = %{name: TestUtil.random_string(20), 
                   password: TestUtil.random_string(20), 
                   phone_number: TestUtil.random_phone_number}

    conn = post conn, "/api/users", user: user_attrs

    user = User.get_user_from_phone_number(user_attrs[:phone_number])

    verify_attrs = %{phone_number: user.phone_number,
                     verification_code: user.verification_code}

    conn = post conn, "/api/verify", verify_attrs

    login_params = %{phone_number: user_attrs[:phone_number],
                     password: "incorrect_password"}

    conn = post conn, "/api/login", login_params

    body = json_response(conn, 400)
    assert 0 == body["success"], "incorrectly logged in with wrong password"
  end

  defp verification_expiration_time_within_limits(request_time, recorded_time) do
    lower_limit = request_time
    upper_limit = request_time
    |> Calendar.DateTime.add!(3)

    case {Calendar.DateTime.after?(recorded_time, lower_limit), Calendar.DateTime.after?(upper_limit, recorded_time)} do
      {true, true} ->
        true
      _ ->
        false
    end
  end
end
