defmodule Tasvir.Twilio do

  # Method used only for testing purposes to not actually send a text
  def send_verification_code(%Plug.Conn{adapter: {Plug.Adapters.Test.Conn, _}}, user), do: nil

  # Production method that actually sends a text
  #  Leave this method defined after the test version, else test version never matches
  def send_verification_code(_, user) do
    body = "Tasvir Verification Code: #{user.verification_code}"

    send_text_message(user.phone_number, body)
  end

  def send_group_link(%Plug.Conn{adapter: {Plug.Adapters.Test.Conn, _}}, phone_number, id), do: nil

  def send_group_link(_, phone_number, id) do
    body = "#{Tasvir.Crypto.encrypt(id)}"

    send_text_message(phone_number, body)
  end

  defp send_text_message(phone_number, message) do
    ExTwilio.Api.create(ExTwilio.Message, [to: phone_number, 
                                           from: Application.get_env(:ex_twilio, :send_number), 
                                           body: message])
  end
end