defmodule Tasvir.PageController do
  use Tasvir.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
