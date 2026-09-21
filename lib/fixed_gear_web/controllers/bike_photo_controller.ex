defmodule FixedGearWeb.BikePhotoController do
  use FixedGearWeb, :controller

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Photo

  def show(conn, %{"id" => id}) do
    case Bikes.get_bike_photo(id) do
      {data, content_type} ->
        case Photo.serve_content_type(data, content_type) do
          {:ok, safe_type} ->
            conn
            |> put_resp_content_type(safe_type, nil)
            |> put_resp_header(
              "cache-control",
              "public, max-age=31536000, immutable"
            )
            |> send_resp(200, data)

          :error ->
            send_resp(conn, 404, "Not found")
        end

      nil ->
        send_resp(conn, 404, "Not found")
    end
  end
end
