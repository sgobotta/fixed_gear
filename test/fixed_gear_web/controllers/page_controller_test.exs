defmodule FixedGearWeb.PageControllerTest do
  use FixedGearWeb.ConnCase, async: true

  test "GET / redirects to the bikes", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/bikes/weight"
  end

  test "GET /bikes redirects to the weight list", %{conn: conn} do
    conn = get(conn, ~p"/bikes")
    assert redirected_to(conn) == ~p"/bikes/weight"
  end

  test "serves the cog favicon", %{conn: conn} do
    conn = get(conn, ~p"/favicon.svg")
    assert conn.status == 200
    assert get_resp_header(conn, "content-type") |> hd() =~ "image/svg"
  end
end
