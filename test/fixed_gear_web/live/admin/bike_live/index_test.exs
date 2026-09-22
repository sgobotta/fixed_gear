defmodule FixedGearWeb.Admin.BikeLive.IndexTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.AccountsFixtures
  import FixedGear.BikesFixtures

  test "redirects unauthenticated visitors", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(conn, ~p"/admin/bikes")
  end

  test "lists bikes for editing", %{conn: conn} do
    bike = bike_fixture(%{name: "Track Bike"})

    {:ok, view, _html} =
      conn
      |> log_in_user(admin_user_fixture())
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
      |> log_in_user(admin_user_fixture())
      |> live(~p"/admin/bikes")

    html = view |> element("#delete-bike-#{bike.id}") |> render_click()

    assert html =~ gettext("Bike deleted")
    refute has_element?(view, "#edit-bike-#{bike.id}")
    refute has_element?(view, "#delete-bike-#{bike.id}")
  end

  test "redirects signed-in users who are not admins", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/ranking/weight"}}} =
             conn
             |> log_in_user(user_fixture())
             |> live(~p"/admin/bikes")
  end

  test "reports a missing bike instead of crashing", %{conn: conn} do
    bike = bike_fixture(%{name: "Gone Bike"})

    {:ok, view, _html} =
      conn
      |> log_in_user(admin_user_fixture())
      |> live(~p"/admin/bikes")

    FixedGear.Bikes.delete_bike(bike)

    html = view |> element("#delete-bike-#{bike.id}") |> render_click()

    assert html =~ gettext("Bike no longer exists")
    refute has_element?(view, "#delete-bike-#{bike.id}")
  end
end
