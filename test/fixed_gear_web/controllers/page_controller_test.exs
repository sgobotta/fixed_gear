defmodule FixedGearWeb.PageControllerTest do
  use FixedGearWeb.ConnCase, async: true

  test "GET / redirects to the ranking", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/ranking"
  end
end
