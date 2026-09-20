defmodule FixedGearWeb.PageController do
  use FixedGearWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
