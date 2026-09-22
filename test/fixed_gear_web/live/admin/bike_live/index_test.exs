defmodule FixedGearWeb.Admin.BikeLive.IndexTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.BikesFixtures

  test "redirects unauthenticated visitors", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(conn, ~p"/admin/bikes")
  end

  test "lists bikes for editing", %{conn: conn} do
    bike = bike_fixture(%{name: "Track Bike"})

    {:ok, view, _html} =
      conn
      |> log_in_user(FixedGear.AccountsFixtures.user_fixture())
      |> live(~p"/admin/bikes")

    assert has_element?(view, "#bikes")
    assert has_element?(view, "#new-bike")
    assert has_element?(view, "#edit-bike-#{bike.id}")
    assert has_element?(view, "#delete-bike-#{bike.id}")
  end

  test "deletes a bike", %{conn: conn} do
    bike = bike_fixture(%{name: "Scrap Bike"})

    {:ok, view, _html} =
      conn
      |> log_in_user(FixedGear.AccountsFixtures.user_fixture())
      |> live(~p"/admin/bikes")

    html = view |> element("#delete-bike-#{bike.id}") |> render_click()

    assert html =~ gettext("Bike deleted")
    refute has_element?(view, "#edit-bike-#{bike.id}")
    refute has_element?(view, "#delete-bike-#{bike.id}")
  end
end
