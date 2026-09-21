defmodule FixedGearWeb.PageControllerTest do
  use FixedGearWeb.ConnCase, async: true

  test "GET / redirects to the ranking", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/ranking/weight"
  end

  test "GET /ranking redirects to the weight ranking", %{conn: conn} do
    conn = get(conn, ~p"/ranking")
    assert redirected_to(conn) == ~p"/ranking/weight"
  end

  test "serves the cog favicon", %{conn: conn} do
    conn = get(conn, ~p"/favicon.svg")
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "image/svg"
  end
end
