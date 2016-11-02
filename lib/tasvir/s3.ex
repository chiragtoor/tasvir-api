defmodule Tasvir.S3 do

  alias ExAws.S3

  # bucket used in S3 does not change
  @bucket Application.get_env(:tasvir, Tasvir.Endpoint)[:bucket]

  def upload(key, path) do
    {:ok, data} = File.read(path)
    
    S3.put_object(@bucket, key, data)
  end

  def download(key) do
    {:ok, download} = S3.get_object(@bucket, key)
    download.body
  end

  def delete(photo_key) do
    S3.delete_object(@bucket, photo_key)
  end
end