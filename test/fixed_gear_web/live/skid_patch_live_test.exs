defmodule FixedGearWeb.SkidPatchLiveTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FixedGear.Bikes
  alias FixedGear.Bikes.Calculations

  test "renders a playground with default gearing and cadence", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    assert has_element?(view, "#skid-patch-form")

    assert has_element?(
             view,
             "#skid-patch-readout",
             "#{Bikes.tooth_label(48)} / #{Bikes.tooth_label(16)}"
           )

    assert has_element?(view, "#chain-ring-value", Bikes.tooth_label(48))
    assert has_element?(view, "#rear-sprocket-value", Bikes.tooth_label(16))
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
    assert has_element?(view, "#hint-speed-playground-toggle")
    assert has_element?(view, "#hint-ratio-playground-toggle")
    assert has_element?(view, "#hint-skid-patches-playground-toggle")
    assert has_element?(view, "#skid-wheel-playground")
    assert has_element?(view, "#skid-wheel-playground-count", "2")

    assert has_element?(
             view,
             ~s(#skid-wheel-playground[data-chain-ring="48"][data-rear-sprocket="16"])
           )

    assert has_element?(view, "#skid-wheel-playground-stage-1-2-48-16")
    assert has_element?(view, "#skid-wheel-playground .skid-wheel-cog")
    assert has_element?(view, "#skid-wheel-playground .skid-wheel-ring")
    assert has_element?(view, "#skid-wheel-playground .skid-wheel-chain")
    refute has_element?(view, "#skid-wheel-playground .skid-wheel-drive")

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
    assert has_element?(view, "#hint-development-playground[aria-hidden=true]")

    assert has_element?(
             view,
             "#hint-development-playground-toggle[aria-expanded=false]"
           )

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

    assert has_element?(
             view,
             "#ratio-band-playground-from-2-7[aria-current=true]",
             gettext(
               "2.7 to 3.0: high speed on flat roads (take care of your knees)"
             )
           )

    refute has_element?(
             view,
             "#ratio-band-playground-over-3-0[aria-current=true]"
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

    assert has_element?(
             view,
             "#skid-patch-readout",
             "#{Bikes.tooth_label(49)} / #{Bikes.tooth_label(16)}"
           )

    assert has_element?(view, "#skid-wheel-playground-count", "32")
    assert has_element?(view, ~s(#skid-wheel-playground[data-patches="16"]))

    assert has_element?(
             view,
             ~s(#skid-wheel-playground[data-ambidextrous="32"])
           )

    assert has_element?(view, "#skid-wheel-playground-stage-16-32-49-16")
    assert skid_patch_mark_count(render(view)) == 32
    assert has_element?(view, ~s(#ratio-motion-playground[data-cadence="90"]))

    assert has_element?(
             view,
             "#ratio-band-playground-over-3-0[aria-current=true]",
             gettext("Over 3.0: pisteritx 🔥")
           )

    refute has_element?(
             view,
             "#ratio-band-playground-from-2-7[aria-current=true]"
           )
  end

  test "redraws sprockets when the patch count stays the same", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/skid-patch")

    assert has_element?(view, "#skid-wheel-playground-stage-1-2-48-16")
    assert has_element?(view, ~s(#skid-wheel-playground[data-patches="1"]))

    view
    |> form("#skid-patch-form", %{
      skid_patch: %{chain_ring: "36", rear_sprocket: "12"}
    })
    |> render_change()

    assert has_element?(view, ~s(#skid-wheel-playground[data-patches="1"]))
    assert has_element?(view, ~s(#skid-wheel-playground[data-ambidextrous="2"]))
    assert has_element?(view, ~s(#skid-wheel-playground[data-chain-ring="36"]))

    assert has_element?(
             view,
             ~s(#skid-wheel-playground[data-rear-sprocket="12"])
           )

    assert has_element?(view, "#skid-wheel-playground-stage-1-2-36-12")
    assert has_element?(view, "#skid-wheel-playground-count", "2")

    view
    |> form("#skid-patch-form", %{
      skid_patch: %{chain_ring: "32", rear_sprocket: "16"}
    })
    |> render_change()

    assert has_element?(view, ~s(#skid-wheel-playground[data-patches="1"]))
    assert has_element?(view, "#skid-wheel-playground-stage-1-1-32-16")
    assert has_element?(view, "#skid-wheel-playground-count", "1")
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
