defmodule FixedGearWeb.PageController do
  use FixedGearWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/ranking/weight")
  end

  def ranking(conn, _params) do
    redirect(conn, to: ~p"/ranking/weight")
  end
end
