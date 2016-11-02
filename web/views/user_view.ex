defmodule Tasvir.UserView do
  use Tasvir.Web, :view

  def render("index.json", %{users: users}) do
    %{data: render_many(users, Tasvir.UserView, "user.json")}
  end

  def render("show.json", %{user: user}) do
    %{data: render_one(user, Tasvir.UserView, "user.json")}
  end

  def render("user.json", %{user: user}) do
    %{name: user.name}
  end
end
