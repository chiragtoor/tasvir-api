defmodule Tasvir.GroupView do
  use Tasvir.Web, :view

  def render("index.json", %{groups: groups}) do
    %{data: render_many(groups, Tasvir.GroupView, "group.json")}
  end

  def render("show.json", %{group: group}) do
    %{data: render_one(group, Tasvir.GroupView, "group.json")}
  end

  def render("group.json", %{group: group}) do
    %{name: group.name}
  end
end
