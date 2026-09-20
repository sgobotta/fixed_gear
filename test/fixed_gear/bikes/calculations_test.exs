defmodule FixedGear.Bikes.CalculationsTest do
  use ExUnit.Case, async: true

  alias FixedGear.Bikes.Calculations

  describe "gear_ratio/2" do
    test "divides chainring by sprocket" do
      assert Calculations.gear_ratio(48, 16) == 3.0
    end

    test "returns nil when gearing is incomplete" do
      assert Calculations.gear_ratio(nil, 16) == nil
      assert Calculations.gear_ratio(48, nil) == nil
    end
  end

  describe "skid_patches/2" do
    test "counts one-sided patches as cog / gcd" do
      assert Calculations.skid_patches(48, 16) == %{
               one_sided: 1,
               ambidextrous: 2
             }
    end

    test "doubles patches when ring/gcd is odd" do
      assert Calculations.skid_patches(49, 16) == %{
               one_sided: 16,
               ambidextrous: 32
             }
    end

    test "does not double when ring/gcd is even" do
      assert Calculations.skid_patches(48, 17) == %{
               one_sided: 17,
               ambidextrous: 17
             }
    end

    test "returns nil when gearing is incomplete" do
      assert Calculations.skid_patches(nil, 16) == nil
    end
  end

  describe "speed_kmh/4" do
    test "uses 700c circumference from tire width" do
      speed = Calculations.speed_kmh(48, 16, 23, 90)
      assert_in_delta speed, 34.0, 0.1
    end

    test "returns nil when tire or gearing is missing" do
      assert Calculations.speed_kmh(48, 16, nil, 90) == nil
      assert Calculations.speed_kmh(nil, 16, 23, 90) == nil
    end
  end

  test "formats display values" do
    assert Calculations.format_weight(Decimal.new("7.1")) == "7.100"
    assert Calculations.format_ratio(3.0) == "3.00"
    assert Calculations.format_speed(33.93) == "33.9"
    assert Calculations.tire_label(25) == "700x25"
    assert Calculations.material_label(:carbon_fiber) == "Carbon fiber"
  end
end
