defmodule FixedGearWeb.SkidPatchLiveTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FixedGear.Bikes.Calculations

  test "renders a playground with default gearing and cadence", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    assert has_element?(view, "#skid-patch-form")
    assert has_element?(view, "#skid-patch-readout", "48t / 16t")
    assert has_element?(view, "#chain-ring-value", "48t")
    assert has_element?(view, "#rear-sprocket-value", "16t")
    assert has_element?(view, ~s(#chain-ring[type="range"][min="28"][max="59"]))

    assert has_element?(
             view,
             ~s(#rear-sprocket[type="range"][min="9"][max="23"])
           )

    assert has_element?(view, "#cadence-value", "60 rpm")
    assert has_element?(view, ~s(#cadence[min="0"][max="180"]))
    assert has_element?(view, "#ratio-motion-playground")

    development =
      Calculations.format_development(Calculations.development_m(48, 16, 28))

    assert has_element?(view, "#development-playground", "#{development} m")
    assert has_element?(view, "#hint-development-playground-toggle")
    assert has_element?(view, "#hint-ratio-playground-toggle")
    assert has_element?(view, "#hint-skid-patches-playground-toggle")
    assert has_element?(view, "#skid-wheel-playground")
    assert has_element?(view, "#skid-wheel-playground-count", "2")

    assert has_element?(
             view,
             ~s([id^="skid-wheel-playground-stage-"][phx-update="ignore"])
           )

    assert skid_patch_mark_count(render(view)) == 2
    assert has_element?(view, "#nav-skid-patch[aria-current=page]")
    assert has_element?(view, "#app-bottom-nav-pill")
    assert has_element?(view, ~s(#app-bottom-nav-stage[phx-update="ignore"]))
    assert has_element?(view, "#nav-ranking")
    refute has_element?(view, "#nav-ranking[aria-current=page]")

    assert has_element?(
             view,
             "a[href='https://www.surplace.fr/ffgc/']",
             "surplace.fr/ffgc"
           )

    assert has_element?(
             view,
             "a[href='https://www.sheldonbrown.com/']",
             "Sheldon Brown"
           )

    assert has_element?(view, "#hint-development-playground.opacity-0")

    assert has_element?(
             view,
             "#hint-development-playground",
             gettext(
               "The distance that the bicycle moves with each revolution of the pedals."
             )
           )

    assert has_element?(
             view,
             "#hint-ratio-playground",
             gettext("Over 3.0: pisteritx 🔥")
           )
  end

  test "updates patches and ratio when gearing changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    view
    |> form("#skid-patch-form", %{
      skid_patch: %{
        chain_ring: "49",
        rear_sprocket: "16",
        tire_width: "28",
        cadence: "90"
      }
    })
    |> render_change()

    assert has_element?(view, "#skid-patch-readout", "49t / 16t")
    assert has_element?(view, "#skid-wheel-playground-count", "32")
    assert has_element?(view, ~s(#skid-wheel-playground[data-patches="16"]))

    assert has_element?(
             view,
             ~s(#skid-wheel-playground[data-ambidextrous="32"])
           )

    assert has_element?(view, "#skid-wheel-playground-stage-16-32")
    assert skid_patch_mark_count(render(view)) == 32
    assert has_element?(view, ~s(#ratio-motion-playground[data-cadence="90"]))
  end

  test "updates speed readout when cadence changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    view
    |> form("#skid-patch-form", %{skid_patch: %{cadence: "160"}})
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

  defp skid_patch_mark_count(html) do
    length(Regex.scan(~r/class="skid-patch(?:\s|")/, html))
  end
end
