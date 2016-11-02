defmodule Tasvir.PhotoView do
  use Tasvir.Web, :view

  def render("index.json", %{photos: photos}) do
    %{data: render_many(photos, Tasvir.PhotoView, "photo.json")}
  end

  def render("show.json", %{photo: photo}) do
    %{data: render_one(photo, Tasvir.PhotoView, "photo.json")}
  end

  def render("photo.json", %{photo: _}) do
    %{success: 1}
  end
end