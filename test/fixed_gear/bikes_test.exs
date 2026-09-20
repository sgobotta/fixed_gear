defmodule FixedGear.BikesTest do
  use FixedGear.DataCase, async: true

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Bike

  import FixedGear.BikesFixtures

  describe "list_bikes_by_weight/0" do
    test "orders lightest first" do
      heavier = bike_fixture(%{weight_kg: "8.200"})
      lighter = bike_fixture(%{weight_kg: "6.500"})

      ids = Enum.map(Bikes.list_bikes_by_weight(), & &1.id)
      light_idx = Enum.find_index(ids, &(&1 == lighter.id))
      heavy_idx = Enum.find_index(ids, &(&1 == heavier.id))
      assert light_idx < heavy_idx
    end

    test "does not load photo binaries" do
      bike_fixture(%{}, png_photo())
      [bike] = Bikes.list_bikes_by_weight()
      assert bike.photo_content_type == "image/png"
      assert is_nil(bike.photo)
    end
  end

  describe "create_bike/2" do
    test "requires name, owner, and weight" do
      assert {:error, changeset} = Bikes.create_bike(%{})
      assert %{name: _, owner: _, weight_kg: _} = errors_on(changeset)
    end

    test "rounds weight to three decimal places" do
      {:ok, bike} =
        Bikes.create_bike(valid_bike_attributes(%{weight_kg: "7.1259"}))

      assert Decimal.eq?(bike.weight_kg, Decimal.new("7.126"))
    end

    test "accepts optional components" do
      {:ok, bike} =
        Bikes.create_bike(
          valid_bike_attributes(%{
            frame_material: "carbon_fiber",
            frame_name: "Dolan Pre Cursa",
            handlebar_material: "aluminum",
            chain_ring: 48,
            rear_sprocket: 16,
            tire_width: 25
          })
        )

      assert bike.frame_material == :carbon_fiber
      assert bike.frame_name == "Dolan Pre Cursa"
      assert bike.handlebar_material == :aluminum
      assert bike.chain_ring == 48
      assert bike.rear_sprocket == 16
      assert bike.tire_width == 25
    end

    test "rejects out of range gearing" do
      assert {:error, changeset} =
               Bikes.create_bike(valid_bike_attributes(%{chain_ring: 12}))

      assert "must be greater than or equal to 28" in errors_on(changeset).chain_ring
    end

    test "treats blank optional selects as nil" do
      {:ok, bike} =
        Bikes.create_bike(
          valid_bike_attributes(%{
            "frame_material" => "",
            "chain_ring" => "",
            "tire_width" => ""
          })
        )

      assert is_nil(bike.frame_material)
      assert is_nil(bike.chain_ring)
      assert is_nil(bike.tire_width)
    end

    test "stores a photo" do
      {:ok, bike} = Bikes.create_bike(valid_bike_attributes(), png_photo())
      {data, type} = Bikes.get_bike_photo(bike.id)
      assert type == "image/png"
      assert data == elem(png_photo(), 0)
    end
  end

  describe "update_bike/3" do
    test "replaces the photo when a new one is uploaded" do
      bike = bike_fixture(%{name: "Old"}, png_photo())
      {webp, type} = webp_photo()

      {:ok, _updated} =
        Bikes.update_bike(
          Bikes.get_bike!(bike.id),
          %{name: "New"},
          {webp, type}
        )

      assert {^webp, "image/webp"} = Bikes.get_bike_photo(bike.id)
    end
  end

  test "get_bike_photo/1 returns nil for missing bikes" do
    assert Bikes.get_bike_photo(0) == nil
    assert Bikes.get_bike_photo("nope") == nil
  end

  test "delete_bike/1 removes the bike" do
    bike = bike_fixture()
    assert {:ok, %Bike{}} = Bikes.delete_bike(bike)
    assert_raise Ecto.NoResultsError, fn -> Bikes.get_bike!(bike.id) end
  end
end
