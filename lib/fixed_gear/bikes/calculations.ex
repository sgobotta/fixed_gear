defmodule FixedGear.Bikes.Calculations do
  @moduledoc """
  Pure gear math for ranking display.

  Ratio is chainring / sprocket. Tire size is used for speed at a
  given cadence, assuming 700c (ISO BSD 622mm).
  """

  @bsd_mm 622
  @tire_widths [23, 25, 28, 32, 35, 38, 44, 50, 56]
  @materials [:aluminum, :steel, :carbon_fiber]
  @chain_ring_min 28
  @chain_ring_max 59
  @sprocket_min 9
  @sprocket_max 23

  def tire_widths, do: @tire_widths
  def materials, do: @materials
  def chain_ring_min, do: @chain_ring_min
  def chain_ring_max, do: @chain_ring_max
  def sprocket_min, do: @sprocket_min
  def sprocket_max, do: @sprocket_max

  @doc """
  Returns chainring / sprocket, or nil when either is missing.
  """
  def gear_ratio(ring, cog)
      when is_integer(ring) and is_integer(cog) and cog > 0 do
    ring / cog
  end

  def gear_ratio(_ring, _cog), do: nil

  @doc """
  One-sided and ambidextrous skid patch counts.

  `one_sided` is `cog / gcd(ring, cog)`. Ambidextrous doubles that
  when `ring / gcd` is odd.
  """
  def skid_patches(ring, cog)
      when is_integer(ring) and is_integer(cog) and cog > 0 do
    gcd = Integer.gcd(ring, cog)
    one_sided = div(cog, gcd)

    ambidextrous =
      if rem(div(ring, gcd), 2) == 1 do
        one_sided * 2
      else
        one_sided
      end

    %{one_sided: one_sided, ambidextrous: ambidextrous}
  end

  def skid_patches(_ring, _cog), do: nil

  @doc """
  Speed in km/h at `rpm` for a 700c tire of the given width.
  """
  def speed_kmh(ring, cog, tire_width, rpm)
      when is_integer(ring) and is_integer(cog) and cog > 0 and
             is_integer(tire_width) and is_number(rpm) do
    ratio = gear_ratio(ring, cog)
    circumference_m = :math.pi() * (@bsd_mm + 2 * tire_width) / 1000
    ratio * circumference_m * rpm * 60 / 1000
  end

  def speed_kmh(_ring, _cog, _tire_width, _rpm), do: nil

  def tire_label(width) when is_integer(width), do: "700x#{width}"
  def tire_label(_width), do: nil

  def material_label(:aluminum), do: "Aluminum"
  def material_label(:steel), do: "Steel"
  def material_label(:carbon_fiber), do: "Carbon fiber"
  def material_label(_), do: nil

  def format_weight(weight) do
    weight
    |> Decimal.round(3)
    |> Decimal.to_float()
    |> :erlang.float_to_binary(decimals: 3)
  end

  def format_ratio(ratio) when is_float(ratio) do
    :erlang.float_to_binary(ratio, decimals: 2)
  end

  def format_speed(speed) when is_float(speed) do
    :erlang.float_to_binary(speed, decimals: 1)
  end
end
