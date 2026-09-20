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
end
