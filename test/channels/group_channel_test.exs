defmodule Tasvir.GroupChannelTest do
  use Tasvir.ChannelCase

  alias Tasvir.GroupChannel

  setup do
    {:ok, _, socket} =
      socket("user_id", %{some: :assign})
      |> subscribe_and_join(GroupChannel, "group:lobby")

    {:ok, socket: socket}
  end

end
