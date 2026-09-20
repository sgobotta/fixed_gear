defmodule FixedGearWeb.PageControllerTest do
  use FixedGearWeb.ConnCase, async: true

  test "GET / renders the ranking", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ gettext("Lightest first")
  end
end
