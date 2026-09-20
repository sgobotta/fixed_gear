defmodule FixedGearWeb.BikePhotoController do
  use FixedGearWeb, :controller

  alias FixedGear.Bikes

  def show(conn, %{"id" => id}) do
    case Bikes.get_bike_photo(id) do
      {data, content_type} ->
        conn
        |> put_resp_content_type(content_type, nil)
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> send_resp(200, data)

      nil ->
        send_resp(conn, 404, "Not found")
    end
  end
end
