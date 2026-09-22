defmodule FixedGearWeb.RankingLiveTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.AccountsFixtures
  import FixedGear.BikesFixtures

  test "renders empty ranking without a cadence slider", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/ranking/weight")

    assert has_element?(view, "#ranking")
    assert has_element?(view, "#ranking-toolbar")
    assert has_element?(view, "#ranking-empty")
    assert has_element?(view, "#tab-weight")
    assert has_element?(view, ~s(#tab-weight[role="tab"][aria-selected="true"]))
    assert has_element?(view, "#nav-ranking[aria-current=page]")
    assert has_element?(view, "#app-bottom-nav-pill")
    assert has_element?(view, ~s(#app-bottom-nav-stage[phx-update="ignore"]))
    assert has_element?(view, "#nav-skid-patch")
    refute has_element?(view, "#nav-skid-patch[aria-current=page]")

    assert has_element?(
             view,
             ~s(#tab-cadence[role="tab"][aria-selected="false"])
           )

    assert has_element?(view, "#ranking-kicker", gettext("Weigh-in"))
    assert has_element?(view, ~s(#cadence-form[aria-hidden="true"]))
    refute has_element?(view, ~s(a[href="/users/log-in"]))
  end

  test "redirects /ranking to the weight ranking", %{conn: conn} do
    conn = get(conn, ~p"/ranking")
    assert redirected_to(conn) == ~p"/ranking/weight"
  end

  test "lists bikes lightest first and expands details", %{conn: conn} do
    heavy =
      bike_fixture(%{
        name: "Heavy",
        owner: "Ava",
        weight_kg: "8.200",
        chain_ring: 48,
        rear_sprocket: 16,
        tire_width: 23
      })

    light = bike_fixture(%{name: "Feather", owner: "Bea", weight_kg: "6.001"})

    {:ok, view, _html} = live(conn, ~p"/ranking/weight")

    assert has_element?(view, "#bike-#{light.id}", "Feather")
    assert has_element?(view, "#bike-#{heavy.id}", "Heavy")
    refute has_element?(view, "#bike-#{heavy.id}-expand-inner")
    refute has_element?(view, "#edit-bike-#{light.id}")

    view
    |> element("#bike-#{heavy.id}-header")
    |> render_click()

    assert_patch(view, ~p"/ranking/#{heavy.id}/weight")
    refute has_element?(view, ~s(#bike-#{heavy.id}-header[phx-key="Enter"]))
    refute has_element?(view, "#bike-#{heavy.id}-header[phx-keydown]")
    assert has_element?(view, "#bike-#{heavy.id}-expand-inner")
    assert has_element?(view, "#bike-#{heavy.id}-expand-inner", "48t / 16t")
    assert has_element?(view, "#ratio-motion-#{heavy.id}")
    assert has_element?(view, "#development-#{heavy.id}")
    assert has_element?(view, "#hint-ratio-#{heavy.id}-toggle")
    assert has_element?(view, "#skid-wheel-#{heavy.id}")
    assert has_element?(view, "#skid-wheel-#{heavy.id} .skid-patch")
    assert has_element?(view, "#skid-wheel-#{heavy.id} .skid-patch-ambi")
    assert has_element?(view, "#skid-wheel-#{heavy.id}-count", "2")
    assert has_element?(view, "#skid-wheel-#{heavy.id}", gettext("both pedals"))
    assert has_element?(view, "#bike-#{heavy.id}-updated", gettext("just now"))

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

    assert has_element?(
             view,
             "#skid-wheel-#{heavy.id}",
             gettext("%{count} one foot", count: 1)
           )

    refute has_element?(
             view,
             "#ratio-motion-#{heavy.id}",
             gettext("both pedals")
           )

    assert has_element?(
             view,
             "#bike-#{heavy.id}-expand-inner",
             gettext("No photo")
           )
  end

  test "keeps a single expanded row and routes each bike", %{conn: conn} do
    first = bike_fixture(%{name: "First", weight_kg: "6.000"})
    second = bike_fixture(%{name: "Second", weight_kg: "7.000"})

    {:ok, view, _html} = live(conn, ~p"/ranking/#{first.id}/weight")

    assert has_element?(view, "#bike-#{first.id}-expand-inner")
    refute has_element?(view, "#bike-#{second.id}-expand-inner")

    view
    |> element("#bike-#{second.id}-header")
    |> render_click()

    assert_patch(view, ~p"/ranking/#{second.id}/weight")
    refute has_element?(view, "#bike-#{first.id}-expand-inner")
    assert has_element?(view, "#bike-#{second.id}-expand-inner")

    view
    |> element("#tab-cadence")
    |> render_click()

    assert_patch(view, ~p"/ranking/#{second.id}/cadence")
    assert has_element?(view, "#bike-#{second.id}-expand-inner")
    assert has_element?(view, "#cadence-form")

    view
    |> element("#bike-#{second.id}-header")
    |> render_click()

    assert_patch(view, ~p"/ranking/cadence")
    refute has_element?(view, "#bike-#{second.id}-expand-inner")
  end

  test "shows bike photos in a landscape frame", %{conn: conn} do
    {png, "image/png"} = landscape_png_photo()
    assert png_size(png) == {6, 4}

    bike = bike_fixture(%{name: "Shot"}, {png, "image/png"})
    {:ok, view, _html} = live(conn, ~p"/ranking/#{bike.id}/weight")

    assert has_element?(view, "#bike-#{bike.id}-photo")
    assert has_element?(view, ~s(#bike-#{bike.id}-photo[class*="aspect-[3/2]"]))
    assert has_element?(view, ~s(#bike-#{bike.id}-photo[class*="self-start"]))

    assert has_element?(
             view,
             ~s(#bike-#{bike.id}-photo img[class*="object-contain"])
           )

    refute has_element?(
             view,
             "#bike-#{bike.id}-expand-inner",
             gettext("No photo")
           )
  end

  test "cadence tab shows the slider and ranks by speed", %{conn: conn} do
    slow =
      bike_fixture(%{
        name: "Low gear",
        weight_kg: "6.000",
        chain_ring: 44,
        rear_sprocket: 18,
        tire_width: 25
      })

    fast =
      bike_fixture(%{
        name: "High gear",
        weight_kg: "8.000",
        chain_ring: 52,
        rear_sprocket: 14,
        tire_width: 25
      })

    {:ok, view, _html} = live(conn, ~p"/ranking/weight")

    html = render(view)
    assert bike_index(html, slow.id) < bike_index(html, fast.id)

    view
    |> element("#tab-cadence")
    |> render_click()

    assert_patch(view, ~p"/ranking/cadence")
    assert has_element?(view, ~s(#tab-cadence[aria-selected="true"]))
    assert has_element?(view, ~s(#tab-weight[aria-selected="false"]))
    assert has_element?(view, ~s(#cadence-form[aria-hidden="false"]))
    assert has_element?(view, "#cadence-dock")
    assert has_element?(view, ~s(#cadence[min="0"][max="180"]))
    assert has_element?(view, "#ranking-kicker", gettext("Cadence"))
    refute has_element?(view, "#ranking-kicker", gettext("Weigh-in"))
    assert has_element?(view, "#cadence-value", "60 rpm")

    html = render(view)
    assert bike_index(html, fast.id) < bike_index(html, slow.id)

    view
    |> element("#bike-#{fast.id}-header")
    |> render_click()

    assert_patch(view, ~p"/ranking/#{fast.id}/cadence")
    assert has_element?(view, "#bike-#{fast.id}-expand-inner", "60 rpm")
    assert has_element?(view, ~s(#ratio-motion-#{fast.id}[data-cadence="60"]))
    assert has_element?(view, ~s(#ratio-motion-#{fast.id}[data-pedal-ms]))

    view
    |> form("#cadence-form", cadence: "100")
    |> render_change()

    assert has_element?(view, "#cadence-value", "100 rpm")
    assert has_element?(view, "#bike-#{fast.id}-expand-inner", "100 rpm")
    assert has_element?(view, ~s(#ratio-motion-#{fast.id}[data-cadence="100"]))
  end

  test "keeps cadence ranking order at 0 rpm", %{conn: conn} do
    slow =
      bike_fixture(%{
        name: "Low gear",
        weight_kg: "6.000",
        chain_ring: 44,
        rear_sprocket: 18,
        tire_width: 25
      })

    fast =
      bike_fixture(%{
        name: "High gear",
        weight_kg: "8.000",
        chain_ring: 52,
        rear_sprocket: 14,
        tire_width: 25
      })

    {:ok, view, _html} = live(conn, ~p"/ranking/cadence")

    html = render(view)
    assert bike_index(html, fast.id) < bike_index(html, slow.id)

    view
    |> form("#cadence-form", cadence: "0")
    |> render_change()

    assert has_element?(view, "#cadence-value", "0 rpm")
    html = render(view)
    assert bike_index(html, fast.id) < bike_index(html, slow.id)
    assert has_element?(view, "#bike-#{fast.id}", "0.0 km/h")
    assert has_element?(view, "#bike-#{slow.id}", "0.0 km/h")
  end

  test "shows an edit pencil for signed-in admins", %{conn: conn} do
    bike = bike_fixture(%{name: "Track"})
    conn = log_in_user(conn, admin_user_fixture())

    {:ok, view, _html} = live(conn, ~p"/ranking/weight")

    assert has_element?(view, "#edit-bike-#{bike.id}")
    assert has_element?(view, ~s(a[href="/admin/bikes"]), gettext("Admin"))
    refute has_element?(view, ~s(a[href="/users/log-in"]))
    refute has_element?(view, "#bike-#{bike.id}-expand-inner")

    {:ok, _view, _html} =
      view
      |> element("#edit-bike-#{bike.id}")
      |> render_click()
      |> follow_redirect(conn, ~p"/admin/bikes/#{bike}/edit")
  end

  test "hides admin controls from signed-in users who are not admins", %{
    conn: conn
  } do
    bike = bike_fixture(%{name: "Track"})
    conn = log_in_user(conn, user_fixture())

    {:ok, view, _html} = live(conn, ~p"/ranking/weight")

    refute has_element?(view, "#edit-bike-#{bike.id}")
    refute has_element?(view, ~s(a[href="/admin/bikes"]), gettext("Admin"))
  end

  defp bike_index(html, id) do
    {index, _} = :binary.match(html, "bike-#{id}")
    index
  end

  defp png_size(
         <<_sig::binary-size(8), _len::32, "IHDR", width::32, height::32,
           _rest::binary>>
       ) do
    {width, height}
  end
end
