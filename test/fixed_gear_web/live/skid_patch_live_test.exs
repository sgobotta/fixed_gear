defmodule FixedGearWeb.SkidPatchLiveTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders a playground with default gearing and cadence", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    assert has_element?(view, "#skid-patch-form")
    assert has_element?(view, "#skid-patch-readout", "48t / 16t")
    assert has_element?(view, "#cadence-value", "90 rpm")
    assert has_element?(view, ~s(#cadence[min="0"][max="180"]))
    assert has_element?(view, "#ratio-motion-playground")
    assert has_element?(view, "#skid-wheel-playground")
    assert has_element?(view, "#skid-wheel-playground-count", "2")
    assert has_element?(view, "#nav-skid-patch[aria-current=page]")
    assert has_element?(view, "#nav-ranking")
    refute has_element?(view, "#nav-ranking[aria-current=page]")

    assert has_element?(
             view,
             "a[href='https://www.surplace.fr/ffgc/']",
             "surplace.fr/ffgc"
           )
  end

  test "updates patches and ratio when gearing changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    view
    |> form("#skid-patch-form", %{
      chain_ring: "49",
      rear_sprocket: "16",
      tire_width: "28",
      cadence: "90"
    })
    |> render_change()

    assert has_element?(view, "#skid-patch-readout", "49t / 16t")
    assert has_element?(view, "#skid-wheel-playground-count", "32")
    assert has_element?(view, ~s(#ratio-motion-playground[data-cadence="90"]))
  end

  test "updates speed readout when cadence changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    view
    |> form("#skid-patch-form", %{cadence: "160"})
    |> render_change()

    assert has_element?(view, "#cadence-value", "160 rpm")
    assert has_element?(view, "#skid-patch-readout", "160 rpm")
    assert has_element?(view, ~s(#ratio-motion-playground[data-cadence="160"]))

    assert has_element?(
             view,
             "#cadence-slider[data-cadence-color='oklch(0.6500 0.2200 25.0000)']"
           )

    assert has_element?(view, "#cadence-slider[data-cadence-progress='88.89%']")
  end
end
