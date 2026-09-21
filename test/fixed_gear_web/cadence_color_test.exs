defmodule FixedGearWeb.CadenceColorTest do
  use ExUnit.Case, async: true

  alias FixedGearWeb.CadenceColor

  test "clamps rpm to 0..180" do
    assert CadenceColor.parse("-10") == 0
    assert CadenceColor.parse("200") == 180
    assert CadenceColor.parse("90") == 90
    assert CadenceColor.parse("nope") == 60
  end

  test "lerps oklch across the advertised bands" do
    assert CadenceColor.css(0) == "oklch(0.8600 0.0700 230.0000)"
    assert CadenceColor.css(60) == "oklch(0.7800 0.1400 230.0000)"
    assert CadenceColor.css(90) == "oklch(0.8000 0.1700 120.0000)"
    assert CadenceColor.css(160) == "oklch(0.6500 0.2200 25.0000)"
    assert CadenceColor.css(180) == "oklch(0.6000 0.2400 310.0000)"
  end

  test "takes the short hue path from red to purple" do
    assert CadenceColor.css(170) == "oklch(0.6250 0.2300 347.5000)"
  end

  test "progress percent fills from 0 to 100 across the slider" do
    assert CadenceColor.progress_percent(0) == 0.0
    assert CadenceColor.progress_percent(90) == 50.0
    assert CadenceColor.progress_percent(180) == 100.0
  end
end
