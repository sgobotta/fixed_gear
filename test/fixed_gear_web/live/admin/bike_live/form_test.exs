defmodule FixedGearWeb.Admin.BikeLive.FormTest do
  use FixedGearWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import FixedGear.BikesFixtures

  setup :register_and_log_in_user

  test "creates a bike", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")

    assert has_element?(view, "#bike-form")

    {:ok, _view, html} =
      view
      |> form("#bike-form",
        bike: %{
          name: "Pre Cursa",
          owner: "Sann",
          weight_kg: "7.125",
          chain_ring: "48",
          rear_sprocket: "16"
        }
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    assert html =~ gettext("Bike created")
    assert html =~ "Pre Cursa"
  end

  test "edits a bike", %{conn: conn} do
    bike = bike_fixture(%{name: "Old Name"})
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/#{bike}/edit")

    {:ok, _view, html} =
      view
      |> form("#bike-form", bike: %{name: "New Name"})
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    assert html =~ gettext("Bike updated")
    assert html =~ "New Name"
  end

  test "uploads a camera photo without a file extension", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")
    {png, _type} = png_photo()

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image",
          content: png,
          type: "image/jpeg"
        }
      ])

    assert render_upload(photo, "image")

    {:ok, _view, _html} =
      view
      |> form("#bike-form",
        bike: %{name: "Cam Photo", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    bike = FixedGear.Bikes.list_bikes() |> hd()
    assert {^png, "image/png"} = FixedGear.Bikes.get_bike_photo(bike.id)
  end

  test "rejects a non-image and still saves the bike", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "notes.txt",
          content: "not a photo",
          type: "text/plain"
        }
      ])

    render_upload(photo, "notes.txt")
    html = render(view)

    assert html =~ gettext("Use JPEG, PNG, or WebP")
    refute has_element?(view, "#save-bike[disabled]")

    {:ok, _view, html} =
      view
      |> form("#bike-form",
        bike: %{name: "No Photo", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    assert html =~ gettext("Bike created")
    bike = FixedGear.Bikes.list_bikes() |> hd()
    assert is_nil(FixedGear.Bikes.get_bike_photo(bike.id))
  end

  test "rejects HEIC at upload so save does not consume it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "image.heic",
          content: "not a real heic",
          type: "image/heic"
        }
      ])

    render_upload(photo, "image.heic")
    html = render(view)

    assert html =~ gettext("Use JPEG, PNG, or WebP")
    refute has_element?(view, "#save-bike[disabled]")

    {:ok, _view, html} =
      view
      |> form("#bike-form",
        bike: %{name: "No HEIC", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    assert html =~ gettext("Bike created")
    bike = FixedGear.Bikes.list_bikes() |> hd()
    assert is_nil(FixedGear.Bikes.get_bike_photo(bike.id))
  end

  test "uploads a photo", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")
    {png, _type} = png_photo()

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "bike.png",
          content: png,
          type: "image/png"
        }
      ])

    assert render_upload(photo, "bike.png")

    {:ok, _view, _html} =
      view
      |> form("#bike-form",
        bike: %{name: "With Photo", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    bike = FixedGear.Bikes.list_bikes() |> hd()
    assert {^png, "image/png"} = FixedGear.Bikes.get_bike_photo(bike.id)
  end

  test "replaces a photo when editing a bike", %{conn: conn} do
    {png, png_type} = png_photo()
    bike = bike_fixture(%{name: "Has Photo"}, {png, png_type})
    {webp, webp_type} = webp_photo()

    {:ok, view, html} = live(conn, ~p"/admin/bikes/#{bike}/edit")
    assert html =~ "v=#{DateTime.to_unix(bike.updated_at)}"

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "bike.webp",
          content: webp,
          type: webp_type
        }
      ])

    assert render_upload(photo, "bike.webp")

    {:ok, _view, _html} =
      view
      |> form("#bike-form")
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    assert {^webp, "image/webp"} = FixedGear.Bikes.get_bike_photo(bike.id)
  end

  test "keeps the selected photo when other fields are invalid", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/bikes/new")
    {png, _type} = png_photo()

    photo =
      file_input(view, "#bike-form", :photo, [
        %{
          last_modified: 1_594_171_879_000,
          name: "bike.png",
          content: png,
          type: "image/png"
        }
      ])

    assert render_upload(photo, "bike.png")

    html =
      view
      |> form("#bike-form",
        bike: %{name: "", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()

    assert html =~ dgettext("errors", "can't be blank")

    {:ok, _view, _html} =
      view
      |> form("#bike-form",
        bike: %{name: "Kept Photo", owner: "Cam", weight_kg: "7.000"}
      )
      |> render_submit()
      |> follow_redirect(conn, ~p"/admin/bikes")

    bike = FixedGear.Bikes.list_bikes() |> hd()
    assert {^png, "image/png"} = FixedGear.Bikes.get_bike_photo(bike.id)
  end

  test "redirects unauthenticated visitors from the form", %{conn: _conn} do
    conn = Phoenix.ConnTest.build_conn()

    assert {:error, {:redirect, %{to: "/users/log-in"}}} =
             live(conn, ~p"/admin/bikes/new")
  end
end
