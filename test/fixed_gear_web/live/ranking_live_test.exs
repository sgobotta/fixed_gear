defmodule FixedGearWeb.RankingLiveTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.BikesFixtures

  test "renders empty ranking", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#ranking")
    assert has_element?(view, "#ranking-empty")
    assert has_element?(view, "#cadence-value", "90 rpm")
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

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#bike-#{light.id}", "Feather")
    assert has_element?(view, "#bike-#{heavy.id}", "Heavy")
    refute has_element?(view, "#bike-#{heavy.id}-expand-inner")

    view
    |> element("#bike-#{heavy.id}-header")
    |> render_click()

    assert has_element?(view, "#bike-#{heavy.id}-expand-inner")
    assert has_element?(view, "#bike-#{heavy.id}-expand-inner", "48t / 16t")
    assert has_element?(view, "#bike-#{heavy.id}-expand-inner", "3.00")
  end

  test "updates cadence speed for expanded bikes", %{conn: conn} do
    bike =
      bike_fixture(%{
        chain_ring: 48,
        rear_sprocket: 16,
        tire_width: 23
      })

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#bike-#{bike.id}-header")
    |> render_click()

    assert has_element?(view, "#cadence-value", "90 rpm")
    assert has_element?(view, "#bike-#{bike.id}-expand-inner", "90 rpm")

    view
    |> form("#cadence-form", cadence: "100")
    |> render_change()

    assert has_element?(view, "#cadence-value", "100 rpm")
    assert has_element?(view, "#bike-#{bike.id}-expand-inner", "100 rpm")
  end
end
