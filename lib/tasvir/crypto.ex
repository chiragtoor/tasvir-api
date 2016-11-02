defmodule Tasvir.Crypto do

  @alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  @coder Hashids.new(salt: System.get_env("ENCRYPTION_KEY"), min_len: 100, alphabet: @alphabet)

  def encrypt(id) do
    Hashids.encode(@coder, id)
  end

  def decrypt(encrypted_id) do
    {:ok, [decrypted_id]} = Hashids.decode(@coder, encrypted_id)

    decrypted_id
  end
end