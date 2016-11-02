defmodule Tasvir.Router do
  use Tasvir.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Tasvir do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", Tasvir do
    pipe_through :api

    resources "/users", UserController, only: [:create]
    post "/verify", UserController, :verify
    post "/login", UserController, :login
    resources "/groups", GroupController, only: [:create, :update]
    post "/groups/:id/accept", GroupController, :accept
    post "/groups/leave", GroupController, :leave
    resources "/photos", PhotoController, only: [:create, :show]
  end
end
