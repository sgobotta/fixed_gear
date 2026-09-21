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

  test "returns 404 when the stored bytes are not a safe image", %{conn: conn} do
    bike =
      %FixedGear.Bikes.Bike{}
      |> Ecto.Changeset.change(%{
        name: "Unsafe",
        owner: "Cam",
        weight_kg: Decimal.new("7.000"),
        photo: "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>",
        photo_content_type: "image/svg+xml"
      })
      |> FixedGear.Repo.insert!()

    conn = get(conn, ~p"/bikes/#{bike}/photo")
    assert response(conn, 404)
  end
end
