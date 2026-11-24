defmodule FixedGearWeb.PageController do
  use FixedGearWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/bikes/weight")
  end
end
