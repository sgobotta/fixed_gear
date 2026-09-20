defmodule FixedGearWeb.BikePhotoControllerTest do
  use FixedGearWeb.ConnCase, async: true

  import FixedGear.BikesFixtures

  test "serves stored photo bytes", %{conn: conn} do
    {png, type} = png_photo()
    bike = bike_fixture(%{}, {png, type})

    conn = get(conn, ~p"/bikes/#{bike}/photo")

    assert response(conn, 200) == png
    assert response_content_type(conn, :png)

    assert "public, max-age=31536000, immutable" in get_resp_header(
             conn,
             "cache-control"
           )
  end

  test "returns 404 when the bike has no photo", %{conn: conn} do
    bike = bike_fixture()
    conn = get(conn, ~p"/bikes/#{bike}/photo")
    assert response(conn, 404)
  end
end
