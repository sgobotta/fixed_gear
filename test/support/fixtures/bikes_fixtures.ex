defmodule FixedGear.BikesFixtures do
  @moduledoc """
  Test helpers for creating bikes.
  """

  alias FixedGear.Bikes

  def unique_bike_name, do: "Bike #{System.unique_integer([:positive])}"

  def valid_bike_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_bike_name(),
      owner: "Rider #{System.unique_integer([:positive])}",
      weight_kg: "7.125"
    })
  end

  def bike_fixture(attrs \\ %{}, photo \\ nil) do
    {:ok, bike} =
      attrs
      |> valid_bike_attributes()
      |> Bikes.create_bike(photo)

    bike
  end

  def png_photo do
    data =
      <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0,
        1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65,
        84, 8, 215, 99, 248, 255, 255, 63, 0, 5, 254, 2, 254, 220, 204, 89, 231,
        0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>

    {data, "image/png"}
  end

  def landscape_png_photo do
    {rgb_png(6, 4), "image/png"}
  end

  defp rgb_png(width, height) do
    row = [0 | List.duplicate(<<200, 80, 40>>, width)]
    raw = IO.iodata_to_binary(List.duplicate(row, height))
    ihdr = <<width::32, height::32, 8, 2, 0, 0, 0>>

    png_signature() <>
      png_chunk("IHDR", ihdr) <>
      png_chunk("IDAT", :zlib.compress(raw)) <>
      png_chunk("IEND", "")
  end

  defp png_signature, do: <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

  defp png_chunk(type, data) do
    crc = :erlang.crc32(type <> data)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end

  def webp_photo do
    {"RIFF" <> <<20::little-32>> <> "WEBPVP8L", "image/webp"}
  end
end
