defmodule FixedGearWeb.CadenceColor do
  @moduledoc """
  Smooth OKLCH colors for the cadence slider.

  Keep stops in sync with `CadenceSlider` in `assets/js/app.js`.
  """

  @min_rpm 0
  @max_rpm 180
  @default_rpm 60

  # {rpm, L, C, H} — hue in degrees
  @stops [
    {0, 0.86, 0.07, 230.0},
    {60, 0.78, 0.14, 230.0},
    {80, 0.75, 0.18, 145.0},
    {100, 0.85, 0.16, 95.0},
    {120, 0.75, 0.18, 55.0},
    {160, 0.65, 0.22, 25.0},
    {180, 0.60, 0.24, 310.0}
  ]

  def min_rpm, do: @min_rpm
  def max_rpm, do: @max_rpm
  def default_rpm, do: @default_rpm

  def clamp(rpm) when is_integer(rpm), do: rpm |> max(@min_rpm) |> min(@max_rpm)
  def clamp(_rpm), do: @default_rpm

  def parse(value) when is_binary(value) do
    case Integer.parse(value) do
      {rpm, _} -> clamp(rpm)
      :error -> @default_rpm
    end
  end

  def parse(rpm) when is_integer(rpm), do: clamp(rpm)
  def parse(_value), do: @default_rpm

  def oklch(rpm) do
    rpm = clamp(rpm) * 1.0
    lerp_stops(@stops, rpm)
  end

  def css(rpm) do
    {l, c, h} = oklch(rpm)
    "oklch(#{fmt(l)} #{fmt(c)} #{fmt(h)})"
  end

  def progress_percent(rpm) do
    rpm = clamp(rpm)
    Float.round(100.0 * rpm / @max_rpm, 2)
  end

  defp lerp_stops([{_rpm, l, c, h}], _at), do: {l, c, h}

  defp lerp_stops([{rpm, l, c, h} | [{next_rpm, _, _, _} | _] = rest], at) do
    if at <= next_rpm do
      t = (at - rpm) / (next_rpm - rpm)
      {nl, nc, nh} = hd_oklch(rest)
      {lerp(l, nl, t), lerp(c, nc, t), lerp_hue(h, nh, t)}
    else
      lerp_stops(rest, at)
    end
  end

  defp hd_oklch([{_rpm, l, c, h} | _]), do: {l, c, h}

  defp lerp(a, b, t), do: a + (b - a) * t

  defp lerp_hue(from, to, t) do
    delta = to - from

    delta =
      cond do
        delta > 180 -> delta - 360
        delta < -180 -> delta + 360
        true -> delta
      end

    wrap_hue(from + delta * t)
  end

  defp wrap_hue(h) do
    h = h - 360.0 * Float.floor(h / 360.0)
    if h < 0, do: h + 360.0, else: h
  end

  defp fmt(n), do: :erlang.float_to_binary(n * 1.0, decimals: 4)
end
